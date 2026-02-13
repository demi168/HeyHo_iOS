import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

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

    func updateFCMToken(userId: String, token: String?) async throws {
        try await db.collection("users").document(userId).setData(["fcmToken": token as Any], merge: true)
    }

    // MARK: - Friends (subcollection: users/{userId}/friends/{friendId})

    func addFriend(userId: String, friendId: String) async throws {
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

    func sendYo(fromUserId: String, toUserId: String) async throws {
        let ref = db.collection("yos").document()
        try ref.setData([
            "fromUserId": fromUserId,
            "toUserId": toUserId,
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
