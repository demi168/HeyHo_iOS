import SwiftUI
import FirebaseFirestore

struct InboxView: View {
    @EnvironmentObject var authState: AuthState
    @State private var yos: [Yo] = []
    @State private var senderNames: [String: String] = [:]
    @State private var listener: ListenerRegistration?

    var body: some View {
        NavigationStack {
            Group {
                if yos.isEmpty {
                    ContentUnavailableView(
                        "Yo はまだ届いていません",
                        systemImage: "tray",
                        description: Text("友だちが Yo を送るとここに表示されます")
                    )
                } else {
                    List(yos) { yo in
                        InboxRow(
                            yo: yo,
                            fromName: senderNames[yo.fromUserId] ?? yo.fromUserId
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
        listener = FirestoreService.shared.inboxListener(userId: uid) { [self] newYos in
            yos = newYos
            Task { await loadSenderNames() }
        }
    }

    private func loadSenderNames() async {
        let ids = Set(yos.map(\.fromUserId))
        var names: [String: String] = [:]
        for id in ids {
            if let user = try? await FirestoreService.shared.getUser(userId: id) {
                names[id] = user.displayName
            }
        }
        await MainActor.run {
            senderNames = names
        }
    }
}

struct InboxRow: View {
    let yo: Yo
    let fromName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fromName)
                    .font(.headline)
                Text(yo.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Yo")
                .font(.title2.bold())
        }
        .padding(.vertical, 8)
    }
}
