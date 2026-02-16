import SwiftUI

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
                            sendYo(to: friend)
                        }
                    }
                }
            }
            .navigationTitle("友だち")
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
            friends = try await FirestoreService.shared.friends(userId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendYo(to friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }
        Task {
            do {
                try await FirestoreService.shared.sendYo(fromUserId: uid, toUserId: friendId)
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
    let onSendYo: () -> Void

    var body: some View {
        HStack {
            Text(friend.displayName)
                .font(.body)
            Spacer()
            Button(justSent ? "送信済み ✓" : "Hey") {
                onSendYo()
            }
            .buttonStyle(.borderedProminent)
            .disabled(justSent)
        }
        .padding(.vertical, 4)
    }
}
