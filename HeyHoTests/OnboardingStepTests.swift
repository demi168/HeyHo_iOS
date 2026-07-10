import Testing

/// OnboardingStep（オンボーディング吹き出しの状態遷移）のテスト
struct OnboardingStepTests {
    @Test func Hey送信でtapToSendからwaitingReplyへ進む() {
        #expect(OnboardingStep.afterSendingHey(current: .tapToSend) == .waitingReply)
    }

    @Test func Hey送信でtapToSend以外は変化しない() {
        #expect(OnboardingStep.afterSendingHey(current: .waitingReply) == .waitingReply)
        #expect(OnboardingStep.afterSendingHey(current: .tapAgain) == .tapAgain)
        #expect(OnboardingStep.afterSendingHey(current: .completed) == .completed)
        #expect(OnboardingStep.afterSendingHey(current: nil) == nil)
    }

    @Test func Ho受信でwaitingReplyからtapAgainへ進む() {
        #expect(OnboardingStep.afterReceivingReply(current: .waitingReply) == .tapAgain)
    }

    @Test func Ho受信でwaitingReply以外は変化しない() {
        #expect(OnboardingStep.afterReceivingReply(current: .tapToSend) == .tapToSend)
        #expect(OnboardingStep.afterReceivingReply(current: .tapAgain) == .tapAgain)
        #expect(OnboardingStep.afterReceivingReply(current: .completed) == .completed)
        #expect(OnboardingStep.afterReceivingReply(current: nil) == nil)
    }

    @Test func LetsGo送信でtapAgainから完了メッセージへ進む() {
        #expect(OnboardingStep.afterSendingLetsGo(current: .tapAgain) == .completed)
    }

    @Test func LetsGo送信でtapAgain以外は変化しない() {
        #expect(OnboardingStep.afterSendingLetsGo(current: .tapToSend) == .tapToSend)
        #expect(OnboardingStep.afterSendingLetsGo(current: .waitingReply) == .waitingReply)
        #expect(OnboardingStep.afterSendingLetsGo(current: .completed) == .completed)
        #expect(OnboardingStep.afterSendingLetsGo(current: nil) == nil)
    }
}
