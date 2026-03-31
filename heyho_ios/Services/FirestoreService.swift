import Foundation
import FirebaseFirestore

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    /// private サブドキュメントへの参照ヘルパー
    private func privateRef(userId: String) -> DocumentReference {
        db.collection("users").document(userId).collection("private").document("data")
    }

    // MARK: - Users

    /// 新規ユーザーを作成する（createdAt はここでのみセット）
    func createUser(userId: String, displayName: String) async throws {
        let ref = db.collection("users").document(userId)
        try await ref.setData([
            "displayName": displayName,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    /// 表示名を更新する（createdAt は上書きしない）
    func updateDisplayName(userId: String, displayName: String) async throws {
        let ref = db.collection("users").document(userId)
        try await ref.setData(["displayName": displayName], merge: true)
    }

    func getUser(userId: String) async throws -> AppUser? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        return try snapshot.data(as: AppUser.self)
    }

    func getUsers(userIds: [String]) async throws -> [AppUser] {
        guard !userIds.isEmpty else { return [] }
        // 個別getで取得（listではなくget権限のみで動作する）
        return try await withThrowingTaskGroup(of: AppUser?.self) { group in
            for uid in userIds {
                group.addTask { [self] in
                    try? await self.getUser(userId: uid)
                }
            }
            var users: [AppUser] = []
            for try await user in group {
                if let user { users.append(user) }
            }
            return users
        }
    }

    /// FCM トークンを private サブドキュメントに保存する
    func updateFCMToken(userId: String, token: String?) async throws {
        try await privateRef(userId: userId).setData(["fcmToken": token as Any], merge: true)
    }

    /// アイコンカラーを更新する（hex文字列、例: "FF6B6B"）
    func updateIconColor(userId: String, colorHex: String) async throws {
        try await db.collection("users").document(userId).setData(["iconColor": colorHex], merge: true)
    }

    // MARK: - Invite Code

    /// ユーザーの招待コードを取得する。未発行なら発行して返す。
    /// inviteCode は private サブドキュメントに保存する。
    func ensureInviteCode(userId: String) async throws -> String {
        let privRef = privateRef(userId: userId)
        let privDoc = try await privRef.getDocument()
        if let data = privDoc.data(),
           let code = data["inviteCode"] as? String,
           !code.isEmpty {
            return code
        }

        let maxRetries = 5
        for _ in 0..<maxRetries {
            let code = Self.generateInviteCode()
            do {
                try await claimInviteCode(code: code, userId: userId)
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

    /// 英数字8桁の招待コードを生成する（紛らわしい文字 O/0/I/1 を除外）
    private static func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return (0..<8).map { _ in String(chars.randomElement()!) }.joined()
    }

    private func claimInviteCode(code: String, userId: String) async throws {
        let codeRef = db.collection("inviteCodes").document(code)
        let privRef = privateRef(userId: userId)
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let codeDoc = try transaction.getDocument(codeRef)
                if codeDoc.exists {
                    errorPointer?.pointee = NSError(domain: "FirestoreService", code: FirestoreService.ErrorCode.codeAlreadyTaken.rawValue, userInfo: [NSLocalizedDescriptionKey: "CodeTaken"])
                    return nil
                }
                transaction.setData(["userId": userId], forDocument: codeRef)
                transaction.setData(["inviteCode": code], forDocument: privRef, merge: true)
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

    /// 自分側の friends ドキュメントのみ作成する。相手側は Cloud Function (onFriendAdded) が自動作成する。
    func addFriend(userId: String, friendId: String) async throws {
        let myRef = db.collection("users").document(userId).collection("friends").document(friendId)
        let existing = try await myRef.getDocument()
        if existing.exists {
            throw NSError(
                domain: "FirestoreService",
                code: FirestoreService.ErrorCode.alreadyFriends.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "既に友達です"]
            )
        }
        try await myRef.setData(["addedAt": FieldValue.serverTimestamp()])
    }

    /// 自分側の friends ドキュメントを削除する。相手側は残る（相手が自分で削除する必要がある）。
    func removeFriend(userId: String, friendId: String) async throws {
        let myRef = db.collection("users").document(userId).collection("friends").document(friendId)
        try await myRef.delete()
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

    /// 各友だちについて「Hey / Ho / Let's Go」の行状態を返す
    func getFriendRowStates(userId: String, friendIds: [String]) async -> [String: FriendRowState] {
        await withTaskGroup(of: (String, FriendRowState).self) { group in
            for friendId in friendIds {
                group.addTask { [self] in
                    // 1人分のクエリ失敗は .sendHey にフォールバックし、他の行に影響させない
                    guard let last = try? await self.getLastHeyHo(me: userId, friendId: friendId) else {
                        return (friendId, .sendHey)
                    }
                    // 相手 → 自分: 相手のメッセージに応じた返信を決定
                    if last.fromUserId == friendId && last.toUserId == userId {
                        switch last.messageType {
                        case .hey: return (friendId, .sendHo)
                        case .ho: return (friendId, .sendLetsGo)
                        case .letsGo: return (friendId, .sendHey)
                        }
                    } else {
                        // 自分 → 相手: 何度でもHeyを送れる
                        return (friendId, .sendHey)
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

}
