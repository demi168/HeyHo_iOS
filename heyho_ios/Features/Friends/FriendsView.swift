import SwiftUI

// FriendRowState は Models/FriendRowState.swift（テスト対象の純粋ロジック）へ移動

/// DEBUG ダミー友だちの ID 接頭辞（実 Firestore には存在しない）
private let debugDummyPrefix = "dummy_"

/// チュートリアルボットの ID 接頭辞（実 Firestore には存在しない）
private let localBotPrefix = "bot_"
/// チュートリアルボット。削除しない限り常に友だちリストに表示する
private let localBotFriend = AppUser(id: "\(localBotPrefix)heyho", displayName: "HeyBoy", iconColor: AppColor.defaultIconHex)
/// ユーザーがボットを削除済みかどうかを永続化するキー
private let botDismissedKey = "heyho.localBotDismissed"

extension AppUser {
    /// DEBUG 用ダミー友だち（実 Firestore に存在しない）かどうか。リリースでは常に false
    var isDebugDummy: Bool { (id ?? "").hasPrefix(debugDummyPrefix) }
    /// ローカルのみの友だち（チュートリアルボット or デバッグダミー）かどうか
    var isLocalFriend: Bool { isDebugDummy || (id ?? "").hasPrefix(localBotPrefix) }
}

#if DEBUG
/// ダミー友だち。アイコンカラーは無料ソリッドカラーからランダムに割り当てる
/// （グローバル let なので起動時に一度だけ評価＝セッション中は固定）
private let debugDummyFriends: [AppUser] = {
    let names = ["JoeyHey", "JohnnyHo", "DeeDeeLetsGo", "TommyHey", "MarkyHo", "RichieLetsGo", "ElvisHey"]
    let palette = AppColor.freeIconPresets.map(\.hex)
    return names.enumerated().map { index, name in
        AppUser(id: "\(debugDummyPrefix)\(index + 1)", displayName: name, iconColor: palette.randomElement())
    }
}()
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
    @State private var showAddFriendSheet = false
    @State private var myIconColorValue: IconColorValue = .solid(hex: AppColor.defaultIconHex)
    @State private var animationState: HeyHoAnimationState = .idle
    @State private var friendToDelete: AppUser?
    @State private var newlyAddedFriendId: String?
    /// 起動ローディング明けの一斉フレームインを発火するトリガー（FriendsView は root で永続のため一度きり）
    @State private var entranceTriggered = false
    @AppStorage(botDismissedKey) private var localBotDismissed = false
    @State private var simulationTask: Task<Void, Never>?

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
                showAddFriendSheet: $showAddFriendSheet,
                resolvedIconColor: resolvedIconColor(for:),
                onSend: sendHeyHo(to:),
                onDelete: { friend in friendToDelete = friend },
                onRefresh: { await loadFriends() },
                entranceTriggered: entranceTriggered
            )

            HeyHoAnimationOverlay(animationState: $animationState)
        }
        .overlay {
            HeyBoyLaunchOverlay(isLoading: isLoading, onReveal: {
                // 起動演出が明けたタイミングで一斉フレームインを発火（一度きり）
                entranceTriggered = true
            })
        }
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
        .fullScreenCover(isPresented: $showMyPage, onDismiss: { Task { await reloadAfterDismiss() } }) {
            MyPageView().environmentObject(authState)
        }
        .sheet(isPresented: $showAddFriendSheet, onDismiss: { Task { await reloadAfterDismiss() } }) {
            AddFriendSheetView(onFriendAdded: { friendId in
                newlyAddedFriendId = friendId
            })
            .environmentObject(authState)
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
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
                name: friend.displayName,
                token: UUID()
            )
            return
        }
        // 一覧に無い場合（追加直後など）は単発取得でフォールバック
        Task { @MainActor in
            let user = try? await FirestoreService.shared.getUser(userId: event.fromUserId)
            animationState = .receiving(
                message: event.messageType,
                iconColor: IconColorValue(firestoreString: user?.iconColor),
                name: user?.displayName ?? String(localized: "Someone"),
                token: UUID()
            )
        }
    }

    private func reloadAfterDismiss() async {
        loadMyColor()
        await loadFriends()
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
            // チュートリアルボット（ユーザーが削除していなければ末尾に追加）
            if !localBotDismissed { list.append(localBotFriend) }
            // 友だちリストを先に表示し、ラリー状態の取得＋受信購読を RallyService に委譲。
            // ローカル友だち（実 Firestore に無い）は無駄クエリになるので除外する
            friends = list
            rallyService.start(userId: uid, friendIds: list.filter { !$0.isLocalFriend }.compactMap(\.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteFriend(_ friend: AppUser) {
        guard let friendId = friend.id else { return }

        if friend.isLocalFriend {
            localBotDismissed = true
            friends.removeAll { $0.id == friendId }
            rallyService.updateFriendIds(friends.filter { !$0.isLocalFriend }.compactMap(\.id))
            return
        }

        guard let uid = authState.currentUserId else { return }
        Task {
            do {
                try await FirestoreService.shared.removeFriend(userId: uid, friendId: friendId)
                await MainActor.run {
                    friends.removeAll { $0.id == friendId }
                    rallyService.updateFriendIds(friends.filter { !$0.isLocalFriend }.compactMap(\.id))
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
        let message = state.sendableMessage
        let name = friend.displayName
        animationState = .sending(message: message, iconColor: myIconColorValue, name: name, token: UUID())
        // 送信アニメが終わるまでこの相手を無効化（letsGo でも再度押せるのはアニメ完了後）
        animatingFriendId = friendId

        // ローカル友だち（ボット・デバッグダミー）は実 Firestore に書けないので
        // 楽観更新＋擬似ラリーをローカルで完結させる
        if friend.isLocalFriend {
            rallyService.markSent(friendId: friendId, messageType: message)
            simulateLocalReply(friendId: friendId, sentState: state)
            return
        }

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

    /// ローカル友だち（ボット・デバッグダミー）からの返信を3秒後に擬似発火する
    /// （Hey→Ho / Ho→LetsGo。LetsGo の後は返信なし）
    private func simulateLocalReply(friendId: String, sentState: FriendRowState) {
        let replyType: MessageType? = switch sentState {
        case .sendHey: .ho
        case .sendHo: .letsGo
        case .sendLetsGo: nil
        }
        guard let replyType else { return }
        simulationTask?.cancel()
        simulationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(3))
                rallyService.simulateLocalReceive(fromUserId: friendId, messageType: replyType)
            } catch is CancellationError {
                // キャンセル済み（正常）
            } catch {
                AppLogger.rally.error("simulateLocalReply: \(error)")
            }
        }
    }
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
    @Binding var showAddFriendSheet: Bool
    let resolvedIconColor: (AppUser) -> IconColorValue
    let onSend: (AppUser) -> Void
    let onDelete: (AppUser) -> Void
    let onRefresh: () async -> Void
    /// 起動明けの一斉フレームインの発火トリガー（ヘッダー＋各行へ伝播）
    var entranceTriggered: Bool = false

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
                    // ぐるぐるスピナーの代わりに、HeyBoy が目ぱちぱちして待機
                    HeyBoyIconView(iconColorValue: myIconColorValue, size: AppSize.iconLarge)
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
                            ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                                FriendRow(
                                    friend: friend,
                                    state: statuses[friend.id ?? ""]?.rowState ?? .sendHey,
                                    isAnimating: animatingFriendId == friend.id,
                                    awaitingReply: statuses[friend.id ?? ""]?.awaitingReply ?? false,
                                    avatarIconColor: resolvedIconColor(friend),
                                    // ヘッダー（delay 0）の次から、上の行ほど早くスタガー登場
                                    entranceDelay: HeyBoyEntrance.stagger * Double(index + 1),
                                    entranceTrigger: entranceTriggered
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
                    // リスト上下端をフェードアウト（ヘッダー/フッターに溶け込ませる）
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.10),
                                .init(color: .black, location: 0.90),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }

            // ヘッダー（最前面に固定）。背景の帯は無し＝リスト側のフェードで溶け込ませる
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, AppSpacing.spXlarge)
                    .padding(.bottom, AppSpacing.spLarge)
            }
            .frame(maxWidth: .infinity)

            // フッター（最前面に固定）。背景の帯は無し＝リスト側のフェードで溶け込ませる
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    Button(action: { showAddFriendSheet = true }) {
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                                .font(.system(size: AppTypography.heading, weight: .black))
                            Text("ADD FRIENDS")
                                .font(.system(size: AppTypography.heading, weight: .black))
                            Spacer()
                        }
                        .foregroundColor(AppColor.textInverse)
                        .padding(.vertical, AppSpacing.spLarge)
                        .frame(minHeight: 60)
                        .background(Capsule().fill(AppColor.buttonPrimaryBackground))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.spXlarge)
                    .padding(.bottom, AppSpacing.spLarge)
                    .padding(.top, AppSpacing.spLarge)
                }
                .frame(maxWidth: .infinity)
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
                    HeyBoyIconView(
                        iconColorValue: myIconColorValue,
                        size: AppSize.iconDefault,
                        showPremiumBadge: isPremium,
                        entranceDelay: 0,
                        entranceTrigger: entranceTriggered
                    )
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
    /// 起動明けフレームインの遅延（nil なら通常表示）
    var entranceDelay: TimeInterval? = nil
    /// 起動明けフレームインの発火トリガー
    var entranceTrigger: Bool = false
    let onSend: () -> Void

    /// 送信不可（アニメ再生中 or 相手の返信待ち）
    private var isDisabled: Bool { isAnimating || awaitingReply }

    var body: some View {
        Button(action: { if !isDisabled { onSend() } }) {
            HStack(spacing: AppSpacing.spMedium) {
                HeyBoyIconView(
                    iconColorValue: avatarIconColor,
                    size: AppSize.iconDefault,
                    entranceDelay: entranceDelay,
                    entranceTrigger: entranceTrigger,
                    isHiding: isDisabled
                )

                Text(friend.displayName)
                    .font(.system(size: AppTypography.display, weight: .black))
                    .foregroundColor(isDisabled ? AppColor.textSecondary : AppColor.textPrimary)
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
                    // Active=黒枠 / Disabled（返信待ち・アニメ中）=グレー枠
                    .strokeBorder(isDisabled ? AppColor.borderDisabled : AppColor.borderStrong, lineWidth: AppSize.borderStrong)
                    .background(Capsule().fill(AppColor.backgroundSecondary))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 起動後フレームイン演出の定数

/// 起動ローディング明けに HeyBoy たちが右下からフレームインする際の設定（一元管理）
private enum HeyBoyEntrance {
    /// 各アイコンの登場をずらすスタガー間隔
    static let stagger: TimeInterval = 0.06
}

// MARK: - 起動ローディング演出

/// 起動時のローディング演出。
/// HeyBoy がポンっと登場 → 目ぱちぱちで待機 → ローディング完了後に少し静止してから画面を覆うまで拡大、
/// フェードアウトして中身を見せる。色はブランドのデフォルト黄色で固定（ユーザーのアイコン色には連動しない）。
private struct HeyBoyLaunchOverlay: View {
    let isLoading: Bool
    /// 画面を覆うアイコンがフェードアウトし始める瞬間に呼ぶ。中身（リスト）のフレームインと重ねる
    var onReveal: () -> Void = {}

    /// HeyBoy の表示サイズ（0=非表示 / iconLarge=登場 / coverSize=画面を覆う）。
    /// scaleEffect ではなく frame サイズを直接アニメすることで、拡大してもベクター（SVG）のまま crisp に保つ
    @State private var iconSize: CGFloat = 0
    @State private var opacity: CGFloat = 1
    /// 演出完了。true で完全に消す
    @State private var finished = false
    /// reveal を二重起動させないためのフラグ
    @State private var revealing = false
    /// ポップイン開始時刻（reveal 時に残りのポップイン時間を計算するため）
    @State private var appearedAt = Date()

    /// ポップインの spring が視覚的に落ち着くまでの目安時間（response 0.45 + バウンド分）
    private let popInSettle: TimeInterval = 0.6
    /// ローディング完了後、拡大に移るまでの静止時間
    private let holdAfterLoaded: TimeInterval = 0.25

    var body: some View {
        if !finished {
            GeometryReader { geo in
                // 画面の対角線より一回り大きくして、拡大しきった時に隅まで覆う
                let coverSize = hypot(geo.size.width, geo.size.height) * 1.1
                ZStack {
                    AppColor.backgroundPrimary
                    HeyBoyIconView(
                        iconColorValue: .solid(hex: AppColor.defaultIconHex),
                        size: iconSize
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(opacity)
                .onAppear {
                    // ポンっと登場
                    appearedAt = Date()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                        iconSize = AppSize.iconLarge
                    }
                    if !isLoading { reveal(to: coverSize) }
                }
                .onChange(of: isLoading) { _, loading in
                    if !loading { reveal(to: coverSize) }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func reveal(to coverSize: CGFloat) {
        guard !revealing else { return }
        revealing = true
        Task { @MainActor in
            // ポップインが視覚的に完了するまで待つ（ローディングが早く終わっても登場演出は見せきる）
            let remainingPopIn = max(0, popInSettle - Date().timeIntervalSince(appearedAt))
            try? await Task.sleep(for: .seconds(remainingPopIn))
            // 完了後の静止
            try? await Task.sleep(for: .seconds(holdAfterLoaded))
            // 画面を覆うまで拡大（frame 駆動なのでベクターのまま crisp）
            withAnimation(.easeIn(duration: 0.40)) { iconSize = coverSize }
            try? await Task.sleep(for: .milliseconds(300))
            // フェードアウト開始と同時に、中身（ヘッダー＋リスト）のフレームインを発火
            onReveal()
            withAnimation(.easeOut(duration: 0.35)) { opacity = 0 }
            try? await Task.sleep(for: .milliseconds(360))
            finished = true
        }
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
        myIconColorValue: .solid(hex: AppColor.defaultIconHex),
        animatingFriendId: nil,
        isPremium: true,
        showMyPage: .constant(false),
        showAddFriendSheet: .constant(false),
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
        myIconColorValue: .solid(hex: AppColor.defaultIconHex),
        animatingFriendId: nil,
        isPremium: true,
        showMyPage: .constant(false),
        showAddFriendSheet: .constant(false),
        resolvedIconColor: { _ in .solid(hex: AppColor.defaultIconHex) },
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
        myIconColorValue: .solid(hex: AppColor.defaultIconHex),
        animatingFriendId: nil,
        isPremium: true,
        showMyPage: .constant(false),
        showAddFriendSheet: .constant(false),
        resolvedIconColor: { _ in .solid(hex: AppColor.defaultIconHex) },
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
