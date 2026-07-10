import Testing
import Foundation

/// FriendListOrder（友だちリストの addedAt 降順ソート）のテスト
struct FriendListOrderTests {
    private static let base = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - orderedIds

    @Test func addedAt降順で新しい友だちが先頭になる() {
        let entries: [(id: String, addedAt: Date?)] = [
            (id: "old", addedAt: Self.base),
            (id: "new", addedAt: Self.base.addingTimeInterval(100)),
            (id: "mid", addedAt: Self.base.addingTimeInterval(50)),
        ]
        #expect(FriendListOrder.orderedIds(entries) == ["new", "mid", "old"])
    }

    @Test func addedAt欠損は末尾に回る() {
        let entries: [(id: String, addedAt: Date?)] = [
            (id: "noDate", addedAt: nil),
            (id: "hasDate", addedAt: Self.base),
        ]
        #expect(FriendListOrder.orderedIds(entries) == ["hasDate", "noDate"])
    }

    @Test func 同時刻と欠損同士はidで安定化する() {
        let entries: [(id: String, addedAt: Date?)] = [
            (id: "b", addedAt: Self.base),
            (id: "a", addedAt: Self.base),
            (id: "d", addedAt: nil),
            (id: "c", addedAt: nil),
        ]
        #expect(FriendListOrder.orderedIds(entries) == ["a", "b", "c", "d"])
    }

    @Test func 入力順に依存せず決定的な順序を返す() {
        var entries: [(id: String, addedAt: Date?)] = [
            (id: "first", addedAt: Self.base.addingTimeInterval(300)),
            (id: "second", addedAt: Self.base.addingTimeInterval(200)),
            (id: "third", addedAt: Self.base.addingTimeInterval(100)),
            (id: "noDate", addedAt: nil),
        ]
        for _ in 0..<50 {
            entries.shuffle()
            #expect(FriendListOrder.orderedIds(entries) == ["first", "second", "third", "noDate"])
        }
    }

    @Test func 空配列は空を返す() {
        #expect(FriendListOrder.orderedIds([]) == [])
    }

    // MARK: - reorder

    /// AppUser の @DocumentID（Optional id）を模した最小のテスト用型
    private struct Item: Equatable {
        var id: String?
        var name: String
    }

    @Test func reorderはid順に並べ直す() {
        let items = [
            Item(id: "c", name: "C"),
            Item(id: "a", name: "A"),
            Item(id: "b", name: "B"),
        ]
        let result = FriendListOrder.reorder(items, toMatch: ["a", "b", "c"], id: { $0.id })
        #expect(result.map(\.name) == ["A", "B", "C"])
    }

    @Test func reorderは順序に無いidを除外し_見つからないidを無視する() {
        let items = [
            Item(id: "a", name: "A"),
            Item(id: "orphan", name: "Orphan"),   // orderedIds に無い → 除外
            Item(id: nil, name: "NoId"),          // id 無し → 除外
        ]
        let result = FriendListOrder.reorder(items, toMatch: ["missing", "a"], id: { $0.id })
        #expect(result.map(\.name) == ["A"])
    }
}
