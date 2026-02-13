import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [AppUser] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @EnvironmentObject var authState: AuthState

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("表示名で検索", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .onSubmit { Task { await search() } }
                }
                Section("検索結果") {
                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        Text("該当するユーザーがいません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(searchResults) { user in
                            AddFriendRow(user: user) {
                                addFriend(user)
                            }
                        }
                    }
                }
            }
            .navigationTitle("友だちを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.count >= 2 {
                Task { await search() }
            } else {
                searchResults = []
            }
        }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await FirestoreService.shared.searchUsers(byDisplayNamePrefix: query)
            if let myId = authState.currentUserId {
                searchResults = searchResults.filter { $0.id != myId }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFriend(_ user: AppUser) {
        guard let uid = authState.currentUserId, let friendId = user.id else { return }
        Task {
            do {
                try await FirestoreService.shared.addFriend(userId: uid, friendId: friendId)
                await MainActor.run { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct AddFriendRow: View {
    let user: AppUser
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(user.displayName)
            Spacer()
            Button("追加") {
                onAdd()
            }
            .buttonStyle(.bordered)
        }
    }
}
