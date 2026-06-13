import SwiftUI

// FriendRowState は Models/FriendRowState.swift（テスト対象の純粋ロジック）へ移動

#if DEBUG
/// DEBUG 表示用ダミー友だちの ID 接頭辞（実 Firestore には存在しない）
private let debugDummyPrefix = "dummy_"
private let debugDummyFriends: [AppUser] = [
    AppUser(id: "\(debugDummyPrefix)1", displayName: "ダミー太郎"),
    AppUser(id: "\(debugDummyPrefix)2", displayName: "ダミー花子"),
    AppUser(id: "\(debugDummyPrefix)3", displayName: "ダミー次郎"),
    AppUser(id: "\(debugDummyPrefix)4", displayName: "ダミー三郎"),
    AppUser(id: "\(debugDummyPrefix)5", displayName: "ダミー梅子"),
    AppUser(id: "\(debugDummyPrefix)6", displayName: "ダミー四郎"),
]

extension AppUser {
    /// DEBUG 用ダミー友だち（実 Firestore に存在しない）かどうか
    var isDebugDummy: Bool { (id ?? "").hasPrefix(debugDummyPrefix) }
}
#endif

// MARK: - FriendsView（データロード担当）

struct FriendsView: View {
    @EnvironmentObject var authState: AuthState
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var rallyService: RallyService
    @State private var friends: [AppUser] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var errorMessage: String?
    /// 送受信アニメーション再生中の相手 ID。アニメが終わる（.idle に戻る）まで送信ボタンを無効化する
    @State private var animatingFriendId: String?
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
                statuses: rallyService.statuses,
                isLoading: isLoading,
                myIconColorValue: myIconColorValue,
                animatingFriendId: animatingFriendId,
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
        .onChange(of: rallyService.incomingEvent) { _, event in
            // リアルタイム受信（B2）・プッシュタップ（B1）共通の受信アニメ発火
            guard let event else { return }
            playReceiveAnimation(event)
        }
        .onChange(of: animationState) { _, newValue in
            // アニメ完了（.idle 復帰）で無効化を解除 → 切り替わりがアニメ後に揃う
            if newValue == .idle { animatingFriendId = nil }
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

    /// 受信イベントから相手のアイコン色・名前を解決して受信アニメを再生する
    private func playReceiveAnimation(_ event: IncomingHeyHo) {
        // 受信アニメが終わるまでこの相手を無効化（active への切り替えはアニメ完了後）
        animatingFriendId = event.fromUserId
        // 友だち一覧にいれば追加取得なしで解決
        if let friend = friends.first(where: { $0.id == event.fromUserId }) {
            animationState = .receiving(
                message: event.messageType,
                iconColor: resolvedIconColor(for: friend),
                name: friend.displayName
            )
            return
        }
        // 一覧に無い場合（追加直後など）は単発取得でフォールバック
        Task { @MainActor in
            let user = try? await FirestoreService.shared.getUser(userId: event.fromUserId)
            animationState = .receiving(
                message: event.messageType,
                iconColor: IconColorValue(firestoreString: user?.iconColor),
                name: user?.displayName ?? String(localized: "Someone")
            )
        }
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
            // 友だちリストを先に表示し、ラリー状態の取得＋受信購読を RallyService に委譲
            friends = list
            rallyService.start(userId: uid, friendIds: list.compactMap(\.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteFriend(_ friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }
        Task {
            do {
                try await FirestoreService.shared.removeFriend(userId: uid, friendId: friendId)
                await MainActor.run {
                    friends.removeAll { $0.id == friendId }
                    rallyService.updateFriendIds(friends.compactMap(\.id))
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func sendHeyHo(to friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }

        // letsGo は全員無料（ゲートなし）
        let state = rallyService.statuses[friendId]?.rowState ?? .sendHey

        // 送信タイプ（行状態 → メッセージ種別）
        let message: MessageType = switch state {
        case .sendHo: .ho
        case .sendLetsGo: .letsGo
        case .sendHey: .hey
        }
        let name = friend.displayName
        animationState = .sending(message: message, iconColor: myIconColorValue, name: name)
        // 送信アニメが終わるまでこの相手を無効化（letsGo でも再度押せるのはアニメ完了後）
        animatingFriendId = friendId

        // DEBUG: ダミー友だちは実 Firestore に書けない（権限エラーになる）ので、
        // 送信を介さず楽観更新＋擬似ラリーをローカルで完結させる
        #if DEBUG
        if friend.isDebugDummy {
            rallyService.markSent(friendId: friendId, messageType: message)
            simulateDummyReply(friendId: friendId, sentState: state)
            return
        }
        #endif

        Task {
            do {
                try await FirestoreService.shared.sendHeyHo(fromUserId: uid, toUserId: friendId)
                // 送信成功 → 相手の返信待ち（ボタン無効化）を楽観更新
                await MainActor.run { rallyService.markSent(friendId: friendId, messageType: message) }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    #if DEBUG
    /// DEBUG: ダミー友だちからの返信を3秒後に擬似発火する（受信アニメ＋無効化解除を実経路と統一）
    private func simulateDummyReply(friendId: String, sentState: FriendRowState) {
        // 自分が送った種別への返信（Hey→Ho / Ho→LetsGo）。LetsGo の後は返信なし
        let replyType: MessageType? = switch sentState {
        case .sendHey: .ho
        case .sendHo: .letsGo
        case .sendLetsGo: nil
        }
        guard let replyType else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            rallyService.debugSimulateReceive(fromUserId: friendId, messageType: replyType)
        }
    }
    #endif
}

// MARK: - FriendsBodyView（純粋 UI・プレビュー可能）

struct FriendsBodyView: View {
    let friends: [AppUser]
    let statuses: [String: FriendRallyStatus]
    let isLoading: Bool
    let myIconColorValue: IconColorValue
    let animatingFriendId: String?
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
                                    state: statuses[friend.id ?? ""]?.rowState ?? .sendHey,
                                    isAnimating: animatingFriendId == friend.id,
                                    awaitingReply: statuses[friend.id ?? ""]?.awaitingReply ?? false,
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
    /// この相手の送受信アニメ再生中（アニメ完了まで無効化）
    let isAnimating: Bool
    /// 自分が最後に送って相手の返信待ち = 送信不可
    let awaitingReply: Bool
    let avatarIconColor: IconColorValue
    let onSend: () -> Void

    /// 送信不可（アニメ再生中 or 相手の返信待ち）
    private var isDisabled: Bool { isAnimating || awaitingReply }

    var body: some View {
        Button(action: { if !isDisabled { onSend() } }) {
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
            // 見た目（dim）は既存演出を流用。最終的な状態表示デザインは別途決定
            .opacity(isDisabled ? 0.55 : 1.0)
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

private let previewStatuses: [String: FriendRallyStatus] = [
    "p1": FriendRallyStatus(rowState: .sendHey, awaitingReply: false),
    "p2": FriendRallyStatus(rowState: .sendHey, awaitingReply: true),   // 返信待ち（無効化）
    "p3": FriendRallyStatus(rowState: .sendHo, awaitingReply: false),
    "p4": FriendRallyStatus(rowState: .sendLetsGo, awaitingReply: false),
    "p5": FriendRallyStatus(rowState: .sendHey, awaitingReply: false),
    "p6": FriendRallyStatus(rowState: .sendHey, awaitingReply: false),
]

#Preview("FriendsBodyView - リスト") {
    FriendsBodyView(
        friends: previewFriends,
        statuses: previewStatuses,
        isLoading: false,
        myIconColorValue: .solid(hex: "FFD700"),
        animatingFriendId: nil,
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
        statuses: [:],
        isLoading: true,
        myIconColorValue: .solid(hex: "FFD700"),
        animatingFriendId: nil,
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
        statuses: [:],
        isLoading: false,
        myIconColorValue: .solid(hex: "FFD700"),
        animatingFriendId: nil,
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
        FriendRow(friend: previewFriends[0], state: .sendHey,    isAnimating: false, awaitingReply: false, avatarIconColor: .solid(hex: "B47850")) {}
        FriendRow(friend: previewFriends[1], state: .sendHey,    isAnimating: false, awaitingReply: true,  avatarIconColor: .solid(hex: "A020F0")) {}
        FriendRow(friend: previewFriends[2], state: .sendHo,     isAnimating: false, awaitingReply: false, avatarIconColor: .solid(hex: "0064FF")) {}
        FriendRow(friend: previewFriends[3], state: .sendLetsGo, isAnimating: false, awaitingReply: false, avatarIconColor: .solid(hex: "FF3030")) {}
        FriendRow(friend: previewFriends[5], state: .sendHey,    isAnimating: false, awaitingReply: false, avatarIconColor: .gradient(presetId: "sunset")) {}
    }
    .padding(.horizontal, AppSpacing.spXlarge)
    .padding(.vertical, AppSpacing.spLarge)
    .frame(maxWidth: .infinity)
    .background(AppColor.backgroundPrimary)
}

#endif
