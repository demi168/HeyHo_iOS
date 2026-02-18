import SwiftUI
import FirebaseFirestore

struct InboxView: View {
    @EnvironmentObject var authState: AuthState
    @State private var heyHos: [HeyHo] = []
    @State private var senderNames: [String: String] = [:]
    @State private var listener: ListenerRegistration?

    var body: some View {
        NavigationStack {
            Group {
                if heyHos.isEmpty {
                    ContentUnavailableView(
                        "メッセージはまだ届いていません",
                        systemImage: "tray",
                        description: Text("友だちが Hey を送るとここに表示されます")
                    )
                } else {
                    List(heyHos) { heyHo in
                        InboxRow(
                            heyHo: heyHo,
                            fromName: senderNames[heyHo.fromUserId] ?? heyHo.fromUserId
                        )
                    }
                }
            }
            .navigationTitle("受信")
            .onAppear {
                startListening()
            }
            .onDisappear {
                listener?.remove()
                listener = nil
            }
        }
    }

    private func startListening() {
        guard let uid = authState.currentUserId else { return }
        listener = FirestoreService.shared.inboxListener(userId: uid) { [self] newHeyHos in
            heyHos = newHeyHos
            Task { await loadSenderNames() }
        }
    }

    private func loadSenderNames() async {
        let ids = Array(Set(heyHos.map(\.fromUserId)))
        guard !ids.isEmpty else { return }

        do {
            let users = try await FirestoreService.shared.getUsers(userIds: ids)
            let names = Dictionary(uniqueKeysWithValues: users.compactMap { user in
                user.id.map { ($0, user.displayName) }
            })
            await MainActor.run {
                senderNames = names
            }
        } catch {
            print("送信者名の取得に失敗: \(error.localizedDescription)")
        }
    }
}

struct InboxRow: View {
    let heyHo: HeyHo
    let fromName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fromName)
                    .font(.headline)
                Text(heyHo.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(heyHo.messageType == .hey ? "Hey" : "Ho")
                .font(.title2.bold())
                .foregroundStyle(heyHo.messageType == .hey ? .blue : .orange)
        }
        .padding(.vertical, 8)
    }
}
