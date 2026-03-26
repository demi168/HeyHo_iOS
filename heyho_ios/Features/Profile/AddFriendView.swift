import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCodeInput = ""
    @State private var isAddingByCode = false
    @State private var errorMessage: String?
    @EnvironmentObject var authState: AuthState

    /// 招待コードの有効な長さ（旧6桁と新8桁の両方を許容）
    private var isCodeValid: Bool {
        let len = inviteCodeInput.trimmingCharacters(in: .whitespaces).count
        return len == 6 || len == 8
    }

    var body: some View {
        NavigationStack {
            List {
                Section("招待コードを入力") {
                    HStack {
                        TextField("招待コード", text: $inviteCodeInput)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.center)
                            .font(.title2.monospaced().weight(.semibold))
                        Button("追加") {
                            addFriendByCode()
                        }
                        .disabled(!isCodeValid || isAddingByCode)
                        .buttonStyle(.borderedProminent)
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
    }

    private func addFriendByCode() {
        let code = inviteCodeInput.trimmingCharacters(in: .whitespaces).uppercased()
        guard (code.count == 6 || code.count == 8), let myId = authState.currentUserId else { return }
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
