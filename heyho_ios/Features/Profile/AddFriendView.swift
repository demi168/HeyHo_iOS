import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [AppUser] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var inviteCodeInput = ""
    @State private var isAddingByCode = false
    @EnvironmentObject var authState: AuthState

    var body: some View {
        NavigationStack {
            List {
                Section("招待コードを入力") {
                    HStack {
                        TextField("6桁のコード", text: $inviteCodeInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.title2.monospacedDigit().weight(.semibold))
                        Button("追加") {
                            addFriendByCode()
                        }
                        .disabled(inviteCodeInput.count != 6 || isAddingByCode)
                        .buttonStyle(.borderedProminent)
                    }
                }
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
            .errorAlert($errorMessage)
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            if newValue.count >= 2 {
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await search()
                }
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

    private func addFriendByCode() {
        let code = inviteCodeInput.trimmingCharacters(in: .whitespaces)
        guard code.count == 6, let myId = authState.currentUserId else { return }
        isAddingByCode = true
        Task {
            defer { isAddingByCode = false }
            do {
                guard let friendId = try await FirestoreService.shared.getUserIdByInviteCode(code) else {
                    errorMessage = "コードが見つかりません"
                    return
                }
                if friendId == myId {
                    errorMessage = "自分のコードです"
                    return
                }
                try await FirestoreService.shared.addFriend(userId: myId, friendId: friendId)
                inviteCodeInput = ""
                dismiss()
            } catch {
                let msg = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
                errorMessage = msg == "既に友達です" ? "すでに友だちです" : msg
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
