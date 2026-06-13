import AVFoundation
import CoreHaptics
import UIKit

/// サウンドとハプティクスを管理するサービス
/// 音声ファイルは Resources/Sounds/ に配置し、ファイル名を soundFileName で参照する。
///
/// ハプティクスは **Core Haptics（CHHapticEngine）** を使う。
/// UIImpactFeedbackGenerator は AVAudioSession が `.playback` でアクティブ保持されていると
/// 抑制されてしまうため。Core Haptics はオーディオ再生中でも抑制されないので、
/// サウンド用のセッションを常時アクティブ（＝音が安定）にしたまま両立できる。
final class FeedbackService {
    static let shared = FeedbackService()
    /// 直近のプレイヤーを数個保持して、重なる短い音が再生途中で解放されないようにする
    private var recentPlayers: [AVAudioPlayer] = []
    private let maxRetainedPlayers = 4

    // Core Haptics
    private var hapticEngine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    // Core Haptics 非対応端末（古い機種・シミュレータ）用フォールバック
    private let impactSharp = UIImpactFeedbackGenerator(style: .rigid)
    private let impactDeep = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        // サイレントモードでも鳴らすためカテゴリは .playback。セッションは常時アクティブで安定再生
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        setupHapticEngine()
        impactSharp.prepare()
        impactDeep.prepare()
        notificationGenerator.prepare()
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
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.play()
                    // 古いプレイヤーから破棄しつつ、再生中インスタンスを保持
                    recentPlayers.append(player)
                    if recentPlayers.count > maxRetainedPlayers { recentPlayers.removeFirst() }
                    return
                } catch {
                    AppLogger.feedback.error("サウンド再生エラー: \(error.localizedDescription)")
                }
            }
        }
        // ファイル未配置時はログだけ出して無音
        AppLogger.feedback.info("サウンドファイル未配置: \(name)")
    }

    // MARK: - ハプティクス（Core Haptics）

    private func setupHapticEngine() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            // 触覚専用にして、サウンド再生用の AVAudioSession に干渉させない（音の途切れ防止）
            engine.playsHapticsOnly = true
            // バックグラウンド復帰やリセット時に再始動する
            engine.resetHandler = { [weak engine] in
                try? engine?.start()
            }
            engine.stoppedHandler = { _ in }
            try engine.start()
            hapticEngine = engine
        } catch {
            AppLogger.feedback.error("Haptic エンジン初期化に失敗: \(error.localizedDescription)")
        }
    }

    /// メッセージ種別ごとに異なる触覚を出す（送信・受信共通）。
    /// hey=シャープ / ho=重め（鈍い）/ letsGo=2連打の完了感。いずれも最大強度で強め
    func playHaptic(for message: MessageType) {
        guard supportsHaptics, let engine = hapticEngine else {
            playHapticFallback(for: message)
            return
        }
        do {
            try engine.start()  // 停止していても確実に動かす
            let player = try engine.makePlayer(with: hapticPattern(for: message))
            try player.start(atTime: 0)
        } catch {
            AppLogger.feedback.error("Haptic 再生に失敗: \(error.localizedDescription)")
            playHapticFallback(for: message)
        }
    }

    /// メッセージ種別ごとの触覚パターン。
    /// Hey/Ho = シャープな単発、LetsGo = シャープな2連発（いずれも intensity/sharpness 最大）
    private func hapticPattern(for message: MessageType) throws -> CHHapticPattern {
        switch message {
        case .hey, .ho:
            return try CHHapticPattern(events: [transient(at: 0, intensity: 1.0, sharpness: 1.0)], parameters: [])
        case .letsGo:
            return try CHHapticPattern(events: [
                transient(at: 0, intensity: 1.0, sharpness: 1.0),
                transient(at: 0.12, intensity: 1.0, sharpness: 1.0),
            ], parameters: [])
        }
    }

    private func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    /// Core Haptics 非対応端末用フォールバック（シミュレータでは無反応）
    private func playHapticFallback(for message: MessageType) {
        switch message {
        case .hey:
            impactSharp.impactOccurred(intensity: 1.0)
            impactSharp.prepare()
        case .ho:
            impactDeep.impactOccurred(intensity: 1.0)
            impactDeep.prepare()
        case .letsGo:
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare()
        }
    }
}
