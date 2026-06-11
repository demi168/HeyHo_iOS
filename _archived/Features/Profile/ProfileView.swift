import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authState: AuthState
    @State private var displayName = ""
    @State private var originalDisplayName = ""
    @State private var isEditingName = false
    @State private var showAddFriend = false
    @State private var errorMessage: String?
    @State private var inviteCode: String?
    @State private var isLoadingInviteCode = false
    @State private var inviteCodeCopied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Display Name") {
                    if isEditingName {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Save") {
                                saveDisplayName()
                            }
                            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                            Button("Cancel") {
                                displayName = originalDisplayName
                                isEditingName = false
                            }
                        }
                    } else {
                        HStack {
                            Text(displayName.isEmpty ? "—" : displayName)
                            Spacer()
                            Button("Edit") {
                                originalDisplayName = displayName
                                isEditingName = true
                            }
                        }
                    }
                }
                Section("My Invite Code") {
                    if isLoadingInviteCode {
                        HStack {
                            ProgressView()
                            Text("Loading...")
                                .foregroundStyle(.secondary)
                        }
                    } else if let code = inviteCode {
                        HStack {
                            Text(code)
                                .font(.title2.monospacedDigit().weight(.bold))
                            Spacer()
                            Button(inviteCodeCopied ? String(localized: "Copied") : String(localized: "Copy")) {
                                UIPasteboard.general.string = code
                                inviteCodeCopied = true
                                Task {
                                    try? await Task.sleep(for: .seconds(2))
                                    await MainActor.run { inviteCodeCopied = false }
                                }
                            }
                            .disabled(inviteCodeCopied)
                        }
                    }
                }
                Section {
                    Button("Add Friend") {
                        showAddFriend = true
                    }
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        signOut()
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                loadDisplayName()
                loadInviteCode()
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .errorAlert($errorMessage)
        }
    }

    private func loadInviteCode() {
        guard let uid = authState.currentUserId else { return }
        isLoadingInviteCode = true
        Task {
            do {
                let code = try await FirestoreService.shared.ensureInviteCode(userId: uid)
                await MainActor.run {
                    inviteCode = code
                    isLoadingInviteCode = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingInviteCode = false
                }
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
