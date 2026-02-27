import SwiftUI

/// 友だちリストの1行が「未返信待ち / Hey / Let's Go / Ho」のどれかを表す
enum FriendRowState {
    case waitingForHo   // 自分が Hey 送付済み・相手の Ho 待ち → Hayed, disabled
    case sendHey
    case sendLetsGo
    case sendHo
}

#if DEBUG
private let debugDummyFriends: [AppUser] = [
    AppUser(id: "dummy_1", displayName: "ダミー 太郎", createdAt: Date(), fcmToken: nil, inviteCode: nil),
    AppUser(id: "dummy_2", displayName: "ダミー 花子", createdAt: Date(), fcmToken: nil, inviteCode: nil),
    AppUser(id: "dummy_3", displayName: "ダミー 次郎", createdAt: Date(), fcmToken: nil, inviteCode: nil),
]
#endif

struct FriendsView: View {
    @EnvironmentObject var authState: AuthState
    @State private var friends: [AppUser] = []
    @State private var rowStates: [String: FriendRowState] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastSentFriendId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    ContentUnavailableView(
                        "友だちがいません",
                        systemImage: "person.2.slash",
                        description: Text("プロフィールから友だちを追加してください")
                    )
                } else {
                    List(friends) { friend in
                        FriendRow(
                            friend: friend,
                            state: rowStates[friend.id ?? ""] ?? .sendHey,
                            justSent: lastSentFriendId == friend.id
                        ) {
                            sendHeyHo(to: friend)
                        }
                    }
                }
            }
            .navigationTitle("友だち")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Image(systemName: "person.fill")
                    }
                }
            }
            .refreshable { await loadFriends() }
            .onAppear { Task { await loadFriends() } }
            .errorAlert($errorMessage)
        }
    }

    private func loadFriends() async {
        guard let uid = authState.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var list = try await FirestoreService.shared.friends(userId: uid)
            #if DEBUG
            list.append(contentsOf: debugDummyFriends)
            #endif
            friends = list
            await loadRowStates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRowStates() async {
        guard let uid = authState.currentUserId else { return }
        let ids = friends.compactMap(\.id)
        guard !ids.isEmpty else { return }
        let states = await FirestoreService.shared.getFriendRowStates(userId: uid, friendIds: ids)
        await MainActor.run { rowStates = states }
    }

    private func sendHeyHo(to friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }
        Task {
            do {
                try await FirestoreService.shared.sendHeyHo(fromUserId: uid, toUserId: friendId)
                await MainActor.run { lastSentFriendId = friendId }
                await loadRowStates()
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await MainActor.run { lastSentFriendId = nil }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct FriendRow: View {
    let friend: AppUser
    let state: FriendRowState
    let justSent: Bool
    let onSend: () -> Void

    private var buttonLabel: String {
        if justSent { return "送信済み ✓" }
        switch state {
        case .waitingForHo: return "Hayed"
        case .sendHey: return "Hey"
        case .sendLetsGo: return "Let's Go"
        case .sendHo: return "Ho"
        }
    }

    private var isDisabled: Bool {
        justSent || state == .waitingForHo
    }

    private var isHighlighted: Bool {
        state == .waitingForHo
    }

    var body: some View {
        HStack {
            Text(friend.displayName)
                .font(.body)
            Spacer()
            Button(buttonLabel) {
                onSend()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
        }
        .padding(.vertical, 4)
        .listRowBackground(isHighlighted ? Color.orange.opacity(0.15) : nil)
    }
}
