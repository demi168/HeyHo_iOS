import Testing

/// FriendRallyStatus.from（最後のメッセージ→ラリー状態の導出）のテスト
struct FriendRallyStatusTests {
    private let me = "me_uid"
    private let friend = "friend_uid"

    @Test func メッセージ無しは初期状態() {
        let s = FriendRallyStatus.from(lastFromUserId: nil, lastMessageType: nil, me: me)
        #expect(s == .initial)
        #expect(s.awaitingReply == false)
        #expect(s.rowState == .sendHey)
    }

    @Test func 自分が最後にHeyかHoなら返信待ち() {
        for type in [MessageType.hey, .ho] {
            let s = FriendRallyStatus.from(lastFromUserId: me, lastMessageType: type, me: me)
            #expect(s.awaitingReply == true)
            #expect(s.rowState == .sendHey)
        }
    }

    @Test func 自分が最後にLetsGoならラリー完了で待たない() {
        // hey→ho→letsGo で1巡完了。次は hey を送れる
        let s = FriendRallyStatus.from(lastFromUserId: me, lastMessageType: .letsGo, me: me)
        #expect(s.awaitingReply == false)
        #expect(s.rowState == .sendHey)
    }

    @Test func 相手がHeyなら自分はHoを返す番() {
        let s = FriendRallyStatus.from(lastFromUserId: friend, lastMessageType: .hey, me: me)
        #expect(s.awaitingReply == false)
        #expect(s.rowState == .sendHo)   // hey.reply == ho
    }

    @Test func 相手がHoなら自分はLetsGoを返す番() {
        let s = FriendRallyStatus.from(lastFromUserId: friend, lastMessageType: .ho, me: me)
        #expect(s.rowState == .sendLetsGo)  // ho.reply == letsGo
    }

    @Test func 相手がLetsGoなら自分はHeyに戻る() {
        let s = FriendRallyStatus.from(lastFromUserId: friend, lastMessageType: .letsGo, me: me)
        #expect(s.rowState == .sendHey)  // letsGo.reply == hey
        #expect(s.awaitingReply == false)
    }
}
