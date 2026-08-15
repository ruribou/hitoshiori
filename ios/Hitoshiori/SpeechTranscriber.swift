import AVFAudio
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechTranscriber {
    enum State: Equatable {
        case idle
        case requestingPermission
        case recording
        case permissionDenied
        case unavailable
    }

    var state: State = .idle
    var transcript = ""
    var errorMessage: String?

    var isRecording: Bool {
        state == .recording
    }

    var isRequestingPermission: Bool {
        state == .requestingPermission
    }

    var needsSettings: Bool {
        state == .permissionDenied
    }

    var isUnavailable: Bool {
        state == .unavailable
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionSessionID: UUID?
    private var wasManuallyStopped = false

    func start() async {
        guard !isRecording, !isRequestingPermission else { return }

        state = .requestingPermission
        errorMessage = nil
        transcript = ""

        guard await requestPermissionsIfNeeded() else { return }
        guard let recognizer else {
            state = .unavailable
            errorMessage = "この端末では日本語の音声認識を利用できません"
            return
        }
        guard recognizer.isAvailable else {
            state = .unavailable
            errorMessage = "音声認識を現在利用できません。しばらくしてからもう一度お試しください"
            return
        }

        cancelCurrentRecognition()
        wasManuallyStopped = false

        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            let sessionID = UUID()

            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }

            recognitionRequest = request
            audioEngine = engine
            recognitionSessionID = sessionID
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, self.recognitionSessionID == sessionID else { return }

                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }

                    if let error, !self.wasManuallyStopped {
                        self.finishRecognition(with: error.localizedDescription)
                    } else if result?.isFinal == true || self.wasManuallyStopped {
                        self.finishRecognition()
                    }
                }
            }

            engine.prepare()
            try engine.start()
            state = .recording
        } catch {
            cancelCurrentRecognition()
            wasManuallyStopped = false
            state = .unavailable
            errorMessage = "音声入力を開始できませんでした: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard isRecording else { return }

        wasManuallyStopped = true
        stopAudioInput()
        state = .idle
    }

    func refreshPermissionState() {
        guard !isRecording, !isRequestingPermission else { return }

        if hasDeniedPermission {
            state = .permissionDenied
            errorMessage = "マイクと音声認識を使うには、設定で許可してください"
        } else if state == .permissionDenied || state == .unavailable {
            state = .idle
            errorMessage = nil
        }
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
        errorMessage = "マイクと音声認識を使うには、設定で許可してください"
    }

    private func finishRecognition(with errorMessage: String? = nil) {
        stopAudioInput()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognitionSessionID = nil
        wasManuallyStopped = false
        state = .idle

        if let errorMessage {
            self.errorMessage = "文字起こしを完了できませんでした: \(errorMessage)"
        }
    }

    private func cancelCurrentRecognition() {
        stopAudioInput()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        recognitionSessionID = nil
    }

    private func stopAudioInput() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest?.endAudio()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
