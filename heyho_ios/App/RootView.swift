import SwiftUI

struct RootView: View {
    @StateObject private var authState = AuthState()

    var body: some View {
        Group {
            if authState.isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authState.isAuthenticated && authState.isProfileSetupComplete {
                MainTabView()
            } else if authState.isAuthenticated {
                // 認証済みだがプロフィール未設定
                EditProfileView(isInitialSetup: true)
            } else {
                SignInView()
            }
        }
        .environmentObject(authState)
        .environmentObject(StoreService.shared)
        .environmentObject(RallyService.shared)
        .onChange(of: authState.currentUserId) { _, uid in
            // サインアウト/アカウント削除で受信購読を解除する（開始は FriendsView 側）
            if uid == nil { RallyService.shared.stop() }
        }
    }
}
