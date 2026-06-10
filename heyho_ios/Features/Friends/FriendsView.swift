import SwiftUI

/// 友だちリストの1行が「Hey / Ho / Let's Go」のどれを送れるかを表す
enum FriendRowState {
    case sendHey        // デフォルト: Heyを送る
    case sendLetsGo     // 相手からHoが返ってきた後: LetsGoを送る
    case sendHo         // 相手からHeyが来た後: Hoを返す
}

#if DEBUG
private let debugDummyFriends: [AppUser] = [
    AppUser(id: "dummy_1", displayName: "ダミー太郎"),
    AppUser(id: "dummy_2", displayName: "ダミー花子"),
    AppUser(id: "dummy_3", displayName: "ダミー次郎"),
    AppUser(id: "dummy_4", displayName: "ダミー三郎"),
    AppUser(id: "dummy_5", displayName: "ダミー梅子"),
    AppUser(id: "dummy_6", displayName: "ダミー四郎"),
]
#endif

// MARK: - FriendsView（データロード担当）

struct FriendsView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService
    @State private var friends: [AppUser] = []
    @State private var rowStates: [String: FriendRowState] = [:]
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var errorMessage: String?
    @State private var lastSentFriendId: String?
    @State private var showMyPage = false
    @State private var showMyPageForAddFriend = false
    @State private var myIconColorValue: IconColorValue = .solid(hex: "FFD700")
    @State private var animationState: HeyHoAnimationState = .idle
    @State private var friendToDelete: AppUser?
    @State private var newlyAddedFriendId: String?

    var body: some View {
        ZStack {
            FriendsBodyView(
                friends: friends,
                rowStates: rowStates,
                isLoading: isLoading,
                myIconColorValue: myIconColorValue,
                lastSentFriendId: lastSentFriendId,
                isPremium: storeService.isPremium,
                showMyPage: $showMyPage,
                showMyPageForAddFriend: $showMyPageForAddFriend,
                resolvedIconColor: resolvedIconColor(for:),
                onSend: sendHeyHo(to:),
                onDelete: { friend in friendToDelete = friend },
                onRefresh: { await loadFriends() }
            )

            HeyHoAnimationOverlay(animationState: $animationState)
        }
        .irisLoading(isLoading: $isLoading)
        .onAppear {
            guard !hasLoadedOnce else { return }
            loadMyColor()
            Task { await loadFriends() }
        }
        .alert("Delete Friend", isPresented: Binding(
            get: { friendToDelete != nil },
            set: { if !$0 { friendToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let friend = friendToDelete { deleteFriend(friend) }
            }
            Button("Cancel", role: .cancel) { friendToDelete = nil }
        } message: {
            if let friend = friendToDelete {
                Text("Delete \(friend.displayName) from friends?")
            }
        }
        .errorAlert($errorMessage)
        .fullScreenCover(isPresented: $showMyPage, onDismiss: {
            Task {
                await authState.refreshCurrentUser()
                loadMyColor()
                await loadFriends()
            }
        }) {
            MyPageView(onFriendAdded: { friendId in
                newlyAddedFriendId = friendId
            }).environmentObject(authState)
        }
        .fullScreenCover(isPresented: $showMyPageForAddFriend, onDismiss: {
            Task {
                await authState.refreshCurrentUser()
                loadMyColor()
                await loadFriends()
            }
        }) {
            MyPageView(focusAddFriend: true, onFriendAdded: { friendId in
                newlyAddedFriendId = friendId
            }).environmentObject(authState)
        }
    }

    private func resolvedIconColor(for friend: AppUser) -> IconColorValue {
        IconColorValue(firestoreString: friend.iconColor)
    }

    private func loadMyColor() {
        if let user = authState.currentUser {
            myIconColorValue = IconColorValue(firestoreString: user.iconColor)
        }
    }

    private func loadFriends() async {
        guard let uid = authState.currentUserId else { return }
        if !hasLoadedOnce { isLoading = true }
        defer { isLoading = false; hasLoadedOnce = true }
        do {
            var list = try await FirestoreService.shared.friends(userId: uid)
            #if DEBUG
            list.append(contentsOf: debugDummyFriends)
            #endif
            // 新しく追加された友だちを先頭に配置
            if let newId = newlyAddedFriendId,
               let idx = list.firstIndex(where: { $0.id == newId }) {
                let newFriend = list.remove(at: idx)
                list.insert(newFriend, at: 0)
                newlyAddedFriendId = nil
            }
            // 友だちリストを先に表示し、rowStates はバックグラウンドで取得
            friends = list
            Task { await loadRowStates() }
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

    private func deleteFriend(_ friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }
        Task {
            do {
                try await FirestoreService.shared.removeFriend(userId: uid, friendId: friendId)
                await MainActor.run {
                    friends.removeAll { $0.id == friendId }
                    rowStates.removeValue(forKey: friendId)
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func sendHeyHo(to friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }

        // letsGo は全員無料（ゲートなし）
        let state = rowStates[friendId] ?? .sendHey

        // 送信タイプに応じたアニメーション
        let name = friend.displayName
        switch state {
        case .sendHo:
            animationState = .sending(message: .ho, iconColor: myIconColorValue, name: name)
        case .sendLetsGo:
            animationState = .sending(message: .letsGo, iconColor: myIconColorValue, name: name)
        default:
            animationState = .sending(message: .hey, iconColor: myIconColorValue, name: name)
        }

        Task {
            do {
                try await FirestoreService.shared.sendHeyHo(fromUserId: uid, toUserId: friendId)
                await MainActor.run { lastSentFriendId = friendId }
                await loadRowStates()
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    await MainActor.run { lastSentFriendId = nil }
                }

                // DEBUGモード: ラリーをシミュレート
                #if DEBUG
                let friendIconColor = resolvedIconColor(for: friend)
                try? await Task.sleep(for: .seconds(3))
                switch state {
                case .sendHey:
                    await MainActor.run {
                        animationState = .receiving(message: .ho, iconColor: friendIconColor, name: name)
                    }
                case .sendHo:
                    await MainActor.run {
                        animationState = .receiving(message: .letsGo, iconColor: friendIconColor, name: name)
                    }
                default:
                    break
                }
                #endif
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - FriendsBodyView（純粋 UI・プレビュー可能）

struct FriendsBodyView: View {
    let friends: [AppUser]
    let rowStates: [String: FriendRowState]
    let isLoading: Bool
    let myIconColorValue: IconColorValue
    let lastSentFriendId: String?
    let isPremium: Bool
    @Binding var showMyPage: Bool
    @Binding var showMyPageForAddFriend: Bool
    let resolvedIconColor: (AppUser) -> IconColorValue
    let onSend: (AppUser) -> Void
    let onDelete: (AppUser) -> Void
    let onRefresh: () async -> Void

    /// ヘッダーの高さ（すりガラス領域 + 下余白）
    private var headerTotalHeight: CGFloat {
        AppSize.iconLarge + AppSpacing.spLarge
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if friends.isEmpty {
                    Spacer()
                    Text("No friends yet")
                        .foregroundColor(AppColor.textInverse).font(.headline)
                    Text("Add friends from your profile")
                        .foregroundColor(AppColor.textInverse.opacity(0.8)).font(.subheadline)
                        .multilineTextAlignment(.center).padding(.top, AppSpacing.spSmall)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.spMedium) {
                            ForEach(friends) { friend in
                                FriendRow(
                                    friend: friend,
                                    state: rowStates[friend.id ?? ""] ?? .sendHey,
                                    justSent: lastSentFriendId == friend.id,
                                    avatarIconColor: resolvedIconColor(friend)
                                ) { onSend(friend) }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        onDelete(friend)
                                    } label: {
                                        Label("Delete Friend", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.spXlarge)
                        // ヘッダー分の上余白 + フッター分の下余白
                        .padding(.top, headerTotalHeight)
                        .padding(.bottom, 80 + AppSpacing.spLarge * 2)
                    }
                    .refreshable { await onRefresh() }
                }
            }

            // すりガラスヘッダー（最前面に固定・下方向にフェードアウト）
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, AppSpacing.spXlarge)
                    .padding(.bottom, AppSpacing.spLarge)
            }
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    //.opacity(0.4)
                    .ignoresSafeArea(edges: .top)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                    )
            )

            // すりガラスフッター（最前面に固定・上方向にフェードアウト）
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    Button(action: { showMyPageForAddFriend = true }) {
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                                .font(.system(size: AppTypography.heading, weight: .black))
                            Text("ADD FRIENDS")
                                .font(.system(size: AppTypography.heading, weight: .black))
                            Spacer()
                        }
                        .foregroundColor(Color.white)
                        .padding(.vertical, AppSpacing.spLarge)
                        .frame(minHeight: 60)
                        .background(Capsule().fill(Color.black))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.spXlarge)
                    .padding(.bottom, AppSpacing.spLarge)
                    .padding(.top, AppSpacing.spLarge)
                }
                .frame(maxWidth: .infinity)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        //.opacity(0.8)
                        .ignoresSafeArea(edges: .bottom)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                )
            }
        }
    }

    private var headerView: some View {
        ZStack(alignment: .center) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(height: AppSize.iconLarge)

            HStack {
                Spacer()
                Button(action: { showMyPage = true }) {
                    HeyBoyIconView(iconColorValue: myIconColorValue, size: AppSize.iconDefault, showPremiumBadge: isPremium)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: AppSize.iconLarge)
        .padding(.bottom, AppSpacing.spLarge)
    }
}

// MARK: - FriendRow

struct FriendRow: View {
    let friend: AppUser
    let state: FriendRowState
    let justSent: Bool
    let avatarIconColor: IconColorValue
    let onSend: () -> Void

    var body: some View {
        Button(action: { if !justSent { onSend() } }) {
            HStack(spacing: AppSpacing.spMedium) {
                HeyBoyIconView(iconColorValue: avatarIconColor, size: AppSize.iconDefault)

                Text(friend.displayName)
                    .font(.system(size: AppTypography.display, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer()
            }
            .padding(.leading, AppSpacing.spLarge)
            .padding(.trailing, AppSpacing.spXlarge)
            .padding(.vertical, AppSpacing.spLarge)
            .frame(minHeight: 80)
            .background(
                Capsule()
                    .strokeBorder(AppColor.borderDefault, lineWidth: AppSize.borderStrong)
                    .background(Capsule().fill(AppColor.backgroundSecondary))
            )
            .opacity(justSent ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG

private let previewFriends: [AppUser] = [
    AppUser(id: "p1", displayName: "Demiflare168", iconColor: "B47850"),
    AppUser(id: "p2", displayName: "Yurinchy",     iconColor: "A020F0"),
    AppUser(id: "p3", displayName: "namename",     iconColor: "0064FF"),
    AppUser(id: "p4", displayName: "pochom-king",  iconColor: "FF3030"),
    AppUser(id: "p5", displayName: "friendsName",  iconColor: "00C8A0"),
    AppUser(id: "p6", displayName: "Heyho_ramone", iconColor: "gradient:sunset"),
]

private let previewRowStates: [String: FriendRowState] = [
    "p1": .sendHey,
    "p2": .sendHey,
    "p3": .sendHo,
    "p4": .sendLetsGo,
    "p5": .sendHey,
    "p6": .sendHey,
]

#Preview("FriendsBodyView - リスト") {
    FriendsBodyView(
        friends: previewFriends,
        rowStates: previewRowStates,
        isLoading: false,
        myIconColorValue: .solid(hex: "FFD700"),
        lastSentFriendId: nil,
        isPremium: true,
        showMyPage: .constant(false),
        showMyPageForAddFriend: .constant(false),
        resolvedIconColor: { IconColorValue(firestoreString: $0.iconColor) },
        onSend: { _ in },
        onDelete: { _ in },
        onRefresh: {}
    )
}

#Preview("FriendsBodyView - ローディング") {
    FriendsBodyView(
        friends: [],
        rowStates: [:],
        isLoading: true,
        myIconColorValue: .solid(hex: "FFD700"),
        lastSentFriendId: nil,
        isPremium: true,
        showMyPage: .constant(false),
        showMyPageForAddFriend: .constant(false),
        resolvedIconColor: { _ in .solid(hex: "FFD700") },
        onSend: { _ in },
        onDelete: { _ in },
        onRefresh: {}
    )
}

#Preview("FriendsBodyView - 友だちなし") {
    FriendsBodyView(
        friends: [],
        rowStates: [:],
        isLoading: false,
        myIconColorValue: .solid(hex: "FFD700"),
        lastSentFriendId: nil,
        isPremium: true,
        showMyPage: .constant(false),
        showMyPageForAddFriend: .constant(false),
        resolvedIconColor: { _ in .solid(hex: "FFD700") },
        onSend: { _ in },
        onDelete: { _ in },
        onRefresh: {}
    )
}

#Preview("FriendRow - 各ステート") {
    VStack(spacing: AppSpacing.spMedium) {
        FriendRow(friend: previewFriends[0], state: .sendHey,    justSent: false, avatarIconColor: .solid(hex: "B47850")) {}
        FriendRow(friend: previewFriends[1], state: .sendHey,    justSent: false, avatarIconColor: .solid(hex: "A020F0")) {}
        FriendRow(friend: previewFriends[2], state: .sendHo,     justSent: false, avatarIconColor: .solid(hex: "0064FF")) {}
        FriendRow(friend: previewFriends[3], state: .sendLetsGo, justSent: false, avatarIconColor: .solid(hex: "FF3030")) {}
        FriendRow(friend: previewFriends[5], state: .sendHey,    justSent: false, avatarIconColor: .gradient(presetId: "sunset")) {}
    }
    .padding(.horizontal, AppSpacing.spXlarge)
    .padding(.vertical, AppSpacing.spLarge)
    .frame(maxWidth: .infinity)
    .background(AppColor.backgroundPrimary)
}

#endif
