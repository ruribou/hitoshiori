import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct SpeechTranscriberTests {
    @Test("無音の音声認識エラーは通常終了として扱う")
    func treatsNoSpeechAsNormalCompletion() {
        let error = NSError(domain: "kAFAssistantErrorDomain", code: 1_110)

        #expect(SpeechTranscriber.message(for: error) == nil)
    }

    @Test("未知の音声認識エラーは日本語の再試行メッセージにする")
    func translatesUnknownErrorToJapanese() {
        let error = NSError(domain: "example", code: 1)

        #expect(SpeechTranscriber.message(for: error) == "文字起こしを完了できませんでした。もう一度お試しください")
    }

    @Test("利用できないマイク入力は日本語のメッセージにする")
    func translatesUnavailableAudioInputToJapanese() {
        #expect(SpeechTranscriber.message(for: SpeechTranscriptionError.audioInputUnavailable) == "この端末のマイク入力を利用できません")
    }
}
