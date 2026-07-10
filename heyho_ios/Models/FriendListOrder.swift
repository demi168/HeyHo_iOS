import Foundation

/// 友だちリストの表示順序（addedAt 降順 = 新しい友だちが上）を確定する純粋ロジック。
/// Firestore の並列取得（withThrowingTaskGroup）は完了順で配列順が毎回変わるため、
/// ここで確定した順序に並べ直して「画面遷移のたびに順番が変わる」のを防ぐ。
enum FriendListOrder {
    /// (id, addedAt) を addedAt 降順に並べた id 配列を返す。
    /// addedAt 欠損は末尾、同時刻・欠損同士は id 昇順で安定化する
    static func orderedIds(_ entries: [(id: String, addedAt: Date?)]) -> [String] {
        entries.sorted { a, b in
            switch (a.addedAt, b.addedAt) {
            case let (lhs?, rhs?):
                if lhs != rhs { return lhs > rhs }
                return a.id < b.id
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return a.id < b.id
            }
        }
        .map(\.id)
    }

    /// orderedIds の順に items を並べ直す（順序が保証されない並列取得の結果を復元する）。
    /// orderedIds に無い要素は除外し、items に無い id は無視する
    static func reorder<T>(_ items: [T], toMatch orderedIds: [String], id: (T) -> String?) -> [T] {
        let byId = Dictionary(
            items.compactMap { item in id(item).map { ($0, item) } },
            uniquingKeysWith: { first, _ in first }
        )
        return orderedIds.compactMap { byId[$0] }
    }
}
