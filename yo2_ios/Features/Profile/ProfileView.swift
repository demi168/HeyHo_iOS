import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authState: AuthState
    @State private var displayName = ""
    @State private var isEditingName = false
    @State private var showAddFriend = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("表示名") {
                    if isEditingName {
                        TextField("表示名", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                        Button("保存") {
                            saveDisplayName()
                        }
                    } else {
                        HStack {
                            Text(displayName.isEmpty ? "—" : displayName)
                            Spacer()
                            Button("変更") {
                                isEditingName = true
                            }
                        }
                    }
                }
                Section {
                    Button("友だちを追加") {
                        showAddFriend = true
                    }
                }
                Section {
                    Button("サインアウト", role: .destructive) {
                        signOut()
                    }
                }
            }
            .navigationTitle("プロフィール")
            .onAppear {
                loadDisplayName()
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .alert("エラー", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
        }
    }

    private func loadDisplayName() {
        guard let uid = authState.currentUserId else { return }
        Task {
            if let user = try? await FirestoreService.shared.getUser(userId: uid) {
                await MainActor.run {
                    displayName = user.displayName
                }
            }
        }
    }

    private func saveDisplayName() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            do {
                try await authState.updateDisplayName(name)
                await MainActor.run { isEditingName = false }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signOut() {
        do {
            try authState.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
