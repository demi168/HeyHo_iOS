import Foundation

/// 初回オンボーディング（HeyBoy行への吹き出し誘導）のステップ。
/// Hey送信 → 待機 → Ho受信後の再タップ → LetsGo送信 → 完了メッセージ、の順に進む
enum OnboardingStep: Equatable {
    /// 「タップしてHey送ってみて」
    case tapToSend
    /// 「友達からレスポンスが来るまでちょっと待つんだ」
    case waitingReply
    /// 「もう一回タップだ！」
    case tapAgain
    /// 完了メッセージ（That's all. Enjoy!）。消灯（→ nil）は View 側のタイマーが行う
    case completed
}

extension OnboardingStep {
    /// Hey送信直後の遷移（tapToSend → waitingReply）。他のステップでは変化しない
    static func afterSendingHey(current: OnboardingStep?) -> OnboardingStep? {
        current == .tapToSend ? .waitingReply : current
    }

    /// Ho受信直後の遷移（waitingReply → tapAgain）。他のステップでは変化しない
    static func afterReceivingReply(current: OnboardingStep?) -> OnboardingStep? {
        current == .waitingReply ? .tapAgain : current
    }

    /// LetsGo送信直後の遷移（tapAgain → completed）。他のステップでは変化しない
    static func afterSendingLetsGo(current: OnboardingStep?) -> OnboardingStep? {
        current == .tapAgain ? .completed : current
    }
}
