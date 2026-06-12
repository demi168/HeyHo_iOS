import AVFoundation
import UIKit

/// サウンドとハプティクスを管理するサービス
/// 音声ファイルは Resources/Sounds/ に配置し、ファイル名を soundFileName で参照する
final class FeedbackService {
    static let shared = FeedbackService()
    private var audioPlayer: AVAudioPlayer?

    private init() {
        // バックグラウンド再生やサイレントモードでも鳴らす設定
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - メッセージ種別ごとの音声ファイル名（拡張子なし）
    // 送信・受信は同じ音を使う（1メッセージ種別 = 1ファイル）。
    // 音声ファイル差し替え時はここのファイル名を変更する

    /// メッセージ種別に対応する音声ファイル名を返す
    private func soundFileName(for message: MessageType) -> String {
        switch message {
        case .hey:    return "hey_default"
        case .ho:     return "ho_default"
        case .letsGo: return "letsgo_default"
        }
    }

    // MARK: - サウンド再生

    /// メッセージに応じた効果音を再生する
    func playSound(for message: MessageType) {
        let name = soundFileName(for: message)
        // mp3, wav, caf, m4a の順で探す
        let extensions = ["mp3", "wav", "caf", "m4a"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.play()
                    return
                } catch {
                    AppLogger.feedback.error("サウンド再生エラー: \(error.localizedDescription)")
                }
            }
        }
        // ファイル未配置時はログだけ出して無音
        AppLogger.feedback.info("サウンドファイル未配置: \(name)")
    }

    // MARK: - ハプティクス

    /// メッセージに応じたハプティクスを発生させる
    func playHaptic(for message: MessageType, isSending: Bool) {
        let generator: UIImpactFeedbackGenerator
        switch message {
        case .hey:
            generator = UIImpactFeedbackGenerator(style: isSending ? .medium : .light)
        case .ho:
            generator = UIImpactFeedbackGenerator(style: isSending ? .medium : .light)
        case .letsGo:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        }
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - まとめて実行

    /// サウンドとハプティクスを同時に実行する
    func playFeedback(for message: MessageType, isSending: Bool) {
        playSound(for: message)
        playHaptic(for: message, isSending: isSending)
    }
}
