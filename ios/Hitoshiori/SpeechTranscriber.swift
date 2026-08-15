import AVFAudio
import Foundation
import Observation
import Speech

private final class AudioNotificationObservers {
    private let notificationCenter: NotificationCenter
    private let observers: [NSObjectProtocol]

    init(
        notificationCenter: NotificationCenter,
        handleInterruption: @escaping @Sendable (Notification) -> Void,
        handleConfigurationChange: @escaping @Sendable () -> Void
    ) {
        self.notificationCenter = notificationCenter
        observers = [
            notificationCenter.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main,
                using: handleInterruption
            ),
            notificationCenter.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: nil,
                queue: .main
            ) { _ in
                handleConfigurationChange()
            }
        ]
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }
}

enum SpeechTranscriptionState: Equatable {
    case idle, requestingPermission, recording, finishing, permissionDenied, unavailable
}

@MainActor
protocol SpeechTranscribing: AnyObject {
    var state: SpeechTranscriptionState { get }
    var transcript: String { get }
    var errorMessage: String? { get }

    func start() async
    func stop()
    func stopAndWaitForFinalResult() async
    func refreshPermissionState()
}

@MainActor
extension SpeechTranscribing {
    var isRecording: Bool {
        state == .recording
    }

    var isFinishing: Bool {
        state == .finishing
    }

    var isRequestingPermission: Bool {
        state == .requestingPermission
    }

    var needsSettings: Bool {
        state == .permissionDenied
    }
}

enum SpeechTranscriptionError: LocalizedError {
    case audioInputUnavailable

    var errorDescription: String? {
        switch self {
        case .audioInputUnavailable:
            "この端末のマイク入力を利用できません"
        }
    }
}

@MainActor
@Observable
final class SpeechTranscriber: SpeechTranscribing {
    typealias State = SpeechTranscriptionState

    private(set) var state: State = .idle
    private(set) var transcript = ""
    private(set) var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let audioSession = AVAudioSession.sharedInstance()
    private let notificationCenter: NotificationCenter
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionSessionID: UUID?
    private var wasManuallyStopped = false
    private var finishingContinuation: CheckedContinuation<Void, Never>?
    private var finishingTimeoutTask: Task<Void, Never>?
    private var notificationObservers: AudioNotificationObservers?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        registerAudioSessionObservers()
    }

    func start() async {
        guard !isRecording, !isFinishing, !isRequestingPermission else { return }

        state = .requestingPermission
        errorMessage = nil
        transcript = ""

        guard await requestPermissionsIfNeeded() else { return }
        guard let recognizer else {
            showUnavailable(message: "この端末では日本語の音声認識を利用できません")
            return
        }
        guard recognizer.isAvailable else {
            showUnavailable(message: "音声認識を現在利用できません。もう一度お試しください")
            return
        }

        do {
            try beginRecognition(with: recognizer)
            state = .recording
        } catch {
            cancelCurrentRecognition()
            wasManuallyStopped = false
            showUnavailable(message: Self.message(for: error) ?? "音声入力を開始できませんでした")
        }
    }

    func stop() {
        guard isRecording else { return }

        wasManuallyStopped = true
        state = .finishing
        stopAudioInput()
        recognitionTask?.finish()
        scheduleFinishingTimeout()
    }

    func stopAndWaitForFinalResult() async {
        stop()
        guard isFinishing else { return }

        await withCheckedContinuation { continuation in
            finishingContinuation = continuation
        }
    }

    func refreshPermissionState() {
        guard !isRecording, !isFinishing, !isRequestingPermission else { return }

        if hasDeniedPermission {
            showPermissionDenied()
        } else if state == .permissionDenied || state == .unavailable {
            state = .idle
            errorMessage = nil
        }
    }

    static func message(for error: Error) -> String? {
        if let transcriptionError = error as? SpeechTranscriptionError {
            return transcriptionError.errorDescription
        }

        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain", [203, 216, 1_110].contains(nsError.code) {
            return nil
        }
        if nsError.domain == NSURLErrorDomain {
            return "文字起こしを完了できませんでした: ネットワークに接続できません"
        }
        return "文字起こしを完了できませんでした。もう一度お試しください"
    }
}

private extension SpeechTranscriber {
    private func beginRecognition(with recognizer: SFSpeechRecognizer) throws {
        cancelCurrentRecognition()
        wasManuallyStopped = false

        try configureAudioSession()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechTranscriptionError.audioInputUnavailable
        }

        let request = makeRecognitionRequest(using: recognizer)
        let sessionID = UUID()
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        recognitionRequest = request
        audioEngine = engine
        recognitionSessionID = sessionID
        recognitionTask = makeRecognitionTask(using: recognizer, request: request, sessionID: sessionID)

        engine.prepare()
        try engine.start()
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func makeRecognitionRequest(
        using recognizer: SFSpeechRecognizer
    ) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        return request
    }

    private func makeRecognitionTask(
        using recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        sessionID: UUID
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.recognitionSessionID == sessionID else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if let error {
                    let message = self.wasManuallyStopped ? nil : Self.message(for: error)
                    self.finishRecognition(with: message)
                } else if result?.isFinal == true {
                    self.finishRecognition()
                }
            }
        }
    }

    private func registerAudioSessionObservers() {
        notificationObservers = AudioNotificationObservers(
            notificationCenter: notificationCenter,
            handleInterruption: { [weak self] notification in
                guard Self.isInterruptionBegan(notification) else { return }
                Task { @MainActor in
                    self?.handleAudioInterruption()
                }
            },
            handleConfigurationChange: { [weak self] in
                Task { @MainActor in
                    self?.handleAudioInterruption()
                }
            }
        )
    }

    nonisolated private static func isInterruptionBegan(_ notification: Notification) -> Bool {
        guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawValue) else {
            return false
        }
        return type == .began
    }

    private func handleAudioInterruption() {
        guard isRecording || isFinishing else { return }
        finishRecognition(cancelTask: true)
    }

    private var hasDeniedPermission: Bool {
        let speechDenied: Bool
        switch SFSpeechRecognizer.authorizationStatus() {
        case .denied, .restricted:
            speechDenied = true
        case .authorized, .notDetermined:
            speechDenied = false
        @unknown default:
            speechDenied = true
        }

        return speechDenied || AVAudioApplication.shared.recordPermission == .denied
    }

    private func requestPermissionsIfNeeded() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .undetermined {
            let microphoneGranted = await requestMicrophonePermission()
            guard microphoneGranted else {
                showPermissionDenied()
                return false
            }
        }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let authorizationStatus = await requestSpeechAuthorization()
            guard authorizationStatus == .authorized else {
                showPermissionDenied()
                return false
            }
        case .denied, .restricted:
            showPermissionDenied()
            return false
        @unknown default:
            showPermissionDenied()
            return false
        }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            showPermissionDenied()
            return false
        }

        return true
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authorizationStatus in
                continuation.resume(returning: authorizationStatus)
            }
        }
    }

    private func showPermissionDenied() {
        state = .permissionDenied
        errorMessage = nil
    }

    private func showUnavailable(message: String) {
        state = .unavailable
        errorMessage = message
    }

    private func scheduleFinishingTimeout() {
        finishingTimeoutTask?.cancel()
        finishingTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.finishRecognition(cancelTask: true)
        }
    }

    private func finishRecognition(with errorMessage: String? = nil, cancelTask: Bool = false) {
        cleanupRecognition(cancelTask: cancelTask)
        wasManuallyStopped = false
        state = .idle
        self.errorMessage = errorMessage
        resolveFinishingWait()
    }

    private func cancelCurrentRecognition() {
        cleanupRecognition(cancelTask: true)
    }

    private func cleanupRecognition(cancelTask: Bool) {
        stopAudioInput()
        if cancelTask {
            recognitionTask?.cancel()
        }
        recognitionTask = nil
        recognitionRequest = nil
        recognitionSessionID = nil
    }

    private func resolveFinishingWait() {
        finishingTimeoutTask?.cancel()
        finishingTimeoutTask = nil
        finishingContinuation?.resume()
        finishingContinuation = nil
    }

    private func stopAudioInput() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest?.endAudio()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
