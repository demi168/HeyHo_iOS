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
    @State private var showPaywall = false
    @State private var myIconColorValue: IconColorValue = .solid(hex: "FFD700")
    @State private var animationState: HeyHoAnimationState = .idle

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
                onRefresh: { await loadFriends() }
            )

            HeyHoAnimationOverlay(animationState: $animationState)
        }
        .onAppear {
            guard !hasLoadedOnce else { return }
            Task { await loadFriends(); await loadMyColor() }
        }
        .errorAlert($errorMessage)
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeService)
        }
        .fullScreenCover(isPresented: $showMyPage, onDismiss: {
            Task { await loadFriends(); await loadMyColor() }
        }) {
            MyPageView().environmentObject(authState)
        }
        .fullScreenCover(isPresented: $showMyPageForAddFriend, onDismiss: {
            Task { await loadFriends(); await loadMyColor() }
        }) {
            MyPageView(focusAddFriend: true).environmentObject(authState)
        }
    }

    private func resolvedIconColor(for friend: AppUser) -> IconColorValue {
        IconColorValue(firestoreString: friend.iconColor)
    }

    private func loadMyColor() async {
        guard let uid = authState.currentUserId else { return }
        if let user = try? await FirestoreService.shared.getUser(userId: uid) {
            await MainActor.run { myIconColorValue = IconColorValue(firestoreString: user.iconColor) }
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
            friends = list
            await loadRowStates()
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

    private func sendHeyHo(to friend: AppUser) {
        guard let uid = authState.currentUserId, let friendId = friend.id else { return }

        // プレミアムゲート: 無料ユーザーは LetsGo を送れない
        let state = rowStates[friendId] ?? .sendHey
        if state == .sendLetsGo && !storeService.isPremium {
            showPaywall = true
            return
        }

        // 送信タイプに応じたアニメーション
        switch state {
        case .sendHo:
            animationState = .sending(message: .ho, iconColor: myIconColorValue)
        case .sendLetsGo:
            animationState = .sending(message: .letsGo, iconColor: myIconColorValue)
        default:
            animationState = .sending(message: .hey, iconColor: myIconColorValue)
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
                        animationState = .receiving(message: .ho, iconColor: friendIconColor)
                    }
                case .sendHo:
                    await MainActor.run {
                        animationState = .receiving(message: .letsGo, iconColor: friendIconColor)
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
    let onRefresh: () async -> Void

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView.padding(.horizontal, AppSpacing.pageHorizontal)

                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if friends.isEmpty {
                    Spacer()
                    Text("友だちがいません")
                        .foregroundColor(AppColor.textInverse).font(.headline)
                    Text("プロフィールから友だちを追加してください")
                        .foregroundColor(AppColor.textInverse.opacity(0.8)).font(.subheadline)
                        .multilineTextAlignment(.center).padding(.top, AppSpacing.inlineGap)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.itemGap) {
                            ForEach(friends) { friend in
                                FriendRow(
                                    friend: friend,
                                    state: rowStates[friend.id ?? ""] ?? .sendHey,
                                    justSent: lastSentFriendId == friend.id,
                                    avatarIconColor: resolvedIconColor(friend),
                                    isPremium: isPremium
                                ) { onSend(friend) }
                            }

                            // Add Friends ボタン
                            Button(action: { showMyPageForAddFriend = true }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "plus")
                                        .font(.system(size: AppTypography.display, weight: .black))
                                    Text("ADD FRIENDS")
                                        .font(.system(size: AppTypography.display, weight: .black))
                                    Spacer()
                                }
                                .foregroundColor(Color.white)
                                .padding(.vertical, AppSpacing.pageVertical)
                                .frame(minHeight: 80)
                                .background(Capsule().fill(Color.black))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, AppSpacing.pageHorizontal)
                        .padding(.bottom, AppSpacing.pageVertical)
                    }
                    .refreshable { await onRefresh() }
                }
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
        .padding(.bottom, AppSpacing.pageVertical)
    }
}

// MARK: - FriendRow

struct FriendRow: View {
    let friend: AppUser
    let state: FriendRowState
    let justSent: Bool
    let avatarIconColor: IconColorValue
    var isPremium: Bool = true
    let onSend: () -> Void

    /// LetsGo がロックされているか
    private var isLetsGoLocked: Bool {
        state == .sendLetsGo && !isPremium
    }

    var body: some View {
        Button(action: { if !justSent { onSend() } }) {
            HStack(spacing: AppSpacing.itemGap) {
                HeyBoyIconView(iconColorValue: avatarIconColor, size: AppSize.iconDefault)

                Text(friend.displayName)
                    .font(.system(size: AppTypography.display, weight: .black))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer()

                // LetsGo ロック表示
                if isLetsGoLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: AppTypography.label))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .padding(.leading, AppSpacing.pageVertical)
            .padding(.trailing, AppSpacing.pageHorizontal)
            .padding(.vertical, AppSpacing.pageVertical)
            .frame(minHeight: 80)
            .background(
                Capsule()
                    .strokeBorder(AppColor.borderDefault, lineWidth: AppSize.borderStrong)
                    .background(Capsule().fill(AppColor.backgroundSecondary))
            )
            .opacity(justSent || isLetsGoLocked ? 0.55 : 1.0)
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
        onRefresh: {}
    )
}

#Preview("FriendRow - 各ステート") {
    VStack(spacing: AppSpacing.itemGap) {
        FriendRow(friend: previewFriends[0], state: .sendHey,    justSent: false, avatarIconColor: .solid(hex: "B47850")) {}
        FriendRow(friend: previewFriends[1], state: .sendHey,    justSent: false, avatarIconColor: .solid(hex: "A020F0")) {}
        FriendRow(friend: previewFriends[2], state: .sendHo,     justSent: false, avatarIconColor: .solid(hex: "0064FF")) {}
        FriendRow(friend: previewFriends[3], state: .sendLetsGo, justSent: false, avatarIconColor: .solid(hex: "FF3030")) {}
        FriendRow(friend: previewFriends[5], state: .sendHey,    justSent: false, avatarIconColor: .gradient(presetId: "sunset")) {}
    }
    .padding(.horizontal, AppSpacing.pageHorizontal)
    .padding(.vertical, AppSpacing.pageVertical)
    .frame(maxWidth: .infinity)
    .background(AppColor.backgroundPrimary)
}

#endif
