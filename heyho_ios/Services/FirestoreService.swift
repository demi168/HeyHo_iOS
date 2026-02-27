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

    // MARK: - Invite Code

    /// ユーザーの招待コードを取得する。未発行なら発行して返す。
    func ensureInviteCode(userId: String) async throws -> String {
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        if let data = userDoc.data(),
           let code = data["inviteCode"] as? String,
           !code.isEmpty {
            return code
        }

        let maxRetries = 5
        for _ in 0..<maxRetries {
            let code = Self.generateInviteCode()
            do {
                try await claimInviteCode(code: code, userId: userId, userRef: userRef)
                return code
            } catch {
                let err = error as NSError
                if err.domain == "FirestoreService" && err.code == FirestoreService.ErrorCode.codeAlreadyTaken.rawValue {
                    continue
                }
                throw error
            }
        }
        throw NSError(domain: "FirestoreService", code: FirestoreService.ErrorCode.failedToGenerateCode.rawValue, userInfo: [NSLocalizedDescriptionKey: "招待コードの生成に失敗しました"])
    }

    private static func generateInviteCode() -> String {
        (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined()
    }

    private func claimInviteCode(code: String, userId: String, userRef: DocumentReference) async throws {
        let codeRef = db.collection("inviteCodes").document(code)
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let codeDoc = try transaction.getDocument(codeRef)
                if codeDoc.exists {
                    errorPointer?.pointee = NSError(domain: "FirestoreService", code: FirestoreService.ErrorCode.codeAlreadyTaken.rawValue, userInfo: [NSLocalizedDescriptionKey: "CodeTaken"])
                    return nil
                }
                transaction.setData(["userId": userId], forDocument: codeRef)
                transaction.setData(["inviteCode": code], forDocument: userRef, merge: true)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    /// 招待コードからユーザーIDを取得する。
    func getUserIdByInviteCode(_ code: String) async throws -> String? {
        let doc = try await db.collection("inviteCodes").document(code).getDocument()
        return doc.data()?["userId"] as? String
    }

    private enum ErrorCode: Int {
        case alreadyFriends = -1
        case codeAlreadyTaken = -2
        case failedToGenerateCode = -3
    }

    // MARK: - Friends (subcollection: users/{userId}/friends/{friendId})

    func addFriend(userId: String, friendId: String) async throws {
        let myRef = db.collection("users").document(userId).collection("friends").document(friendId)
        let otherRef = db.collection("users").document(friendId).collection("friends").document(userId)
        // トランザクションで重複追加を防ぐ
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let existingDoc = try transaction.getDocument(myRef)
                if existingDoc.exists {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: FirestoreService.ErrorCode.alreadyFriends.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: "既に友達です"]
                    )
                    return nil
                }
                transaction.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: myRef)
                transaction.setData(["addedAt": FieldValue.serverTimestamp()], forDocument: otherRef)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func friendIds(userId: String) async throws -> [String] {
        let snapshot = try await db.collection("users").document(userId).collection("friends").getDocuments()
        return snapshot.documents.map(\.documentID)
    }

    func friends(userId: String) async throws -> [AppUser] {
        let ids = try await friendIds(userId: userId)
        guard !ids.isEmpty else { return [] }
        // getUsers はバッチ処理済み（in クエリ10件上限に対応）
        return try await getUsers(userIds: ids)
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

    // MARK: - HeyHos

    /// 2人の間の最後の1件のメッセージを取得する（行状態の判定用）
    /// in: を2フィールドに使うと Firestore のルール評価が拒否するため、
    /// 送信方向ごとに別クエリを並列実行して最新の1件を返す
    func getLastHeyHo(me: String, friendId: String) async throws -> HeyHo? {
        async let sentSnap = db.collection("heyhos")
            .whereField("fromUserId", isEqualTo: me)
            .whereField("toUserId", isEqualTo: friendId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        async let receivedSnap = db.collection("heyhos")
            .whereField("fromUserId", isEqualTo: friendId)
            .whereField("toUserId", isEqualTo: me)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        let (sent, received) = try await (sentSnap, receivedSnap)
        let s = sent.documents.first.flatMap { try? $0.data(as: HeyHo.self) }
        let r = received.documents.first.flatMap { try? $0.data(as: HeyHo.self) }
        switch (s, r) {
        case (nil, _): return r
        case (_, nil): return s
        case (let s?, let r?):
            let sc = s.createdAt ?? .distantPast
            let rc = r.createdAt ?? .distantPast
            return sc > rc ? s : r
        }
    }

    /// 各友だちについて「未返信(Hayed) / Hey / Let's Go / Ho」の行状態を返す
    func getFriendRowStates(userId: String, friendIds: [String]) async -> [String: FriendRowState] {
        await withTaskGroup(of: (String, FriendRowState).self) { group in
            for friendId in friendIds {
                group.addTask { [self] in
                    // 1人分のクエリ失敗は .sendHey にフォールバックし、他の行に影響させない
                    guard let last = try? await self.getLastHeyHo(me: userId, friendId: friendId) else {
                        return (friendId, .sendHey)
                    }
                    // 相手 → 自分
                    if last.fromUserId == friendId && last.toUserId == userId {
                        switch last.messageType {
                        case .hey: return (friendId, .sendHo)
                        case .ho: return (friendId, .sendLetsGo)
                        case .letsGo: return (friendId, .sendHey)
                        }
                    } else {
                        // 自分 → 相手
                        switch last.messageType {
                        case .hey: return (friendId, .waitingForHo)
                        case .ho, .letsGo: return (friendId, .sendHey)
                        }
                    }
                }
            }
            var result: [String: FriendRowState] = [:]
            for await (friendId, state) in group {
                result[friendId] = state
            }
            return result
        }
    }

    /// 最後のメッセージを取得して、次に送るべきメッセージタイプを決定
    private func getNextMessageType(fromUserId: String, toUserId: String) async throws -> MessageType {
        guard let last = try await getLastHeyHo(me: fromUserId, friendId: toUserId) else {
            return .hey
        }
        // 相手 → 自分
        if last.fromUserId == toUserId {
            switch last.messageType {
            case .hey: return .ho
            case .ho: return .letsGo
            case .letsGo: return .hey
            }
        }
        // 自分 → 相手
        return .hey
    }

    func sendHeyHo(fromUserId: String, toUserId: String) async throws {
        let messageType = try await getNextMessageType(fromUserId: fromUserId, toUserId: toUserId)
        let ref = db.collection("heyhos").document()
        try await ref.setData([
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "messageType": messageType.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func inboxListener(userId: String, onUpdate: @escaping ([HeyHo]) -> Void) -> ListenerRegistration {
        db.collection("heyhos")
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    if error != nil { onUpdate([]) }
                    return
                }
                let heyHos = documents.compactMap { doc -> HeyHo? in
                    try? doc.data(as: HeyHo.self)
                }
                onUpdate(heyHos)
            }
    }
}
