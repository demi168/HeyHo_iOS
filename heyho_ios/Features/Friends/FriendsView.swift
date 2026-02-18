import SwiftUI

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendHeyHo(to friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }
        Task {
            do {
                try await FirestoreService.shared.sendHeyHo(fromUserId: uid, toUserId: friendId)
                await MainActor.run {
                    lastSentFriendId = friendId
                    // 1秒後にリセット
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        lastSentFriendId = nil
                    }
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
    let justSent: Bool
    let onSend: () -> Void

    var body: some View {
        HStack {
            Text(friend.displayName)
                .font(.body)
            Spacer()
            Button(justSent ? "送信済み ✓" : "Hey") {
                onSend()
            }
            .buttonStyle(.borderedProminent)
            .disabled(justSent)
        }
        .padding(.vertical, 4)
    }
}
