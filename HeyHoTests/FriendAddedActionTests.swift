import Testing

/// FriendAddedAction（友だち追加イベント受信時のアクション判定）のテスト
struct FriendAddedActionTests {
    @Test func 既存かつリスナー経路はskip() {
        #expect(FriendAddedAction.decide(alreadyInList: true, isFromPushTap: false) == .skip)
    }

    @Test func 既存かつPushタップはhighlightExisting() {
        #expect(FriendAddedAction.decide(alreadyInList: true, isFromPushTap: true) == .highlightExisting)
    }

    @Test func 未存在かつリスナー経路はfetchAndInsert() {
        #expect(FriendAddedAction.decide(alreadyInList: false, isFromPushTap: false) == .fetchAndInsert)
    }

    @Test func 未存在かつPushタップはfetchAndInsert() {
        #expect(FriendAddedAction.decide(alreadyInList: false, isFromPushTap: true) == .fetchAndInsert)
    }
}
