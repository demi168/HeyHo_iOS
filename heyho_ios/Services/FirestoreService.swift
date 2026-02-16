import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Users

    func createOrUpdateUser(userId: String, displayName: String, fcmToken: String?) async throws {
        let ref = db.collection("users").document(userId)
        let data: [String: Any] = [
            "displayName": displayName,
            "createdAt": FieldValue.serverTimestamp(),
            "fcmToken": fcmToken as Any
        ]
        try await ref.setData(data, merge: true)
    }

    func getUser(userId: String) async throws -> AppUser? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return try snapshot.data(as: AppUser.self)
    }

    func getUsers(userIds: [String]) async throws -> [AppUser] {
        guard !userIds.isEmpty else { return [] }
        // Firestoreの`in`クエリは最大10件まで
        let batchSize = 10
        var allUsers: [AppUser] = []

        for i in stride(from: 0, to: userIds.count, by: batchSize) {
            let end = min(i + batchSize, userIds.count)
            let batch = Array(userIds[i..<end])
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments()
            let users = snapshot.documents.compactMap { try? $0.data(as: AppUser.self) }
            allUsers.append(contentsOf: users)
        }

        return allUsers
    }

    func updateFCMToken(userId: String, token: String?) async throws {
        try await db.collection("users").document(userId).setData(["fcmToken": token as Any], merge: true)
    }

    // MARK: - Friends (subcollection: users/{userId}/friends/{friendId})

    func addFriend(userId: String, friendId: String) async throws {
        // 既に友達かチェック
        let existingFriend = try? await db.collection("users")
            .document(userId)
            .collection("friends")
            .document(friendId)
            .getDocument()

        if existingFriend?.exists == true {
            throw NSError(domain: "FirestoreService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "既に友達です"
            ])
        }

        let batch = db.batch()
        let myRef = db.collection("users").document(userId).collection("friends").document(friendId)
        let otherRef = db.collection("users").document(friendId).collection("friends").document(userId)
        batch.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: myRef)
        batch.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: otherRef)
        try await batch.commit()
    }

    func friendIds(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users").document(userId).collection("friends").getDocuments()
        return snapshot.documents.map(\.documentID)
    }

    func friends(userId: String) async throws -> [AppUser] {
        let ids = try await friendIds(userId: userId)
        guard !ids.isEmpty else { return [] }
        let snapshot = try await db.collection("users").whereField(FieldPath.documentID(), in: ids).getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: AppUser.self)
        }
    }

    func searchUsers(byDisplayNamePrefix prefix: String, limit: Int = 20) async throws -> [AppUser] {
        guard !prefix.isEmpty else { return [] }
        let snapshot = try await db.collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: prefix)
            .whereField("displayName", isLessThan: prefix + "\u{f8ff}")
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: AppUser.self)
        }
    }

    // MARK: - Yos

    /// 最後のメッセージを取得して、次に送るべきメッセージタイプを決定
    private func getNextMessageType(fromUserId: String, toUserId: String) async throws -> String {
        // 2人の間の最後のメッセージを取得
        let snapshot = try await db.collection("yos")
            .whereField("fromUserId", in: [fromUserId, toUserId])
            .whereField("toUserId", in: [fromUserId, toUserId])
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let lastMessage = snapshot.documents.first,
              let lastYo = try? lastMessage.data(as: Yo.self) else {
            // メッセージがない場合は「Hey」で開始
            return "hey"
        }

        // 最後のメッセージが相手から自分への場合
        if lastYo.fromUserId == toUserId && lastYo.toUserId == fromUserId {
            // 相手が「Hey」を送ってきた → 「Ho」で返す
            if lastYo.messageType == "hey" {
                return "ho"
            }
            // 相手が「Ho」を送ってきた → 「Hey」で返す
            else {
                return "hey"
            }
        }

        // 最後のメッセージが自分から相手への場合 → 新しいラリーとして「Hey」で開始
        return "hey"
    }

    func sendYo(fromUserId: String, toUserId: String) async throws {
        let messageType = try await getNextMessageType(fromUserId: fromUserId, toUserId: toUserId)
        let ref = db.collection("yos").document()
        try await ref.setData([
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "messageType": messageType,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func inboxListener(userId: String, onUpdate: @escaping ([Yo]) -> Void) -> ListenerRegistration {
        db.collection("yos")
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if error != nil { onUpdate([]) }
                    return
                }
                let yos = documents.compactMap { doc -> Yo? in
                    try? doc.data(as: Yo.self)
                }
                onUpdate(yos)
            }
    }
}
