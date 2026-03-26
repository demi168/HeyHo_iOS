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
    }
}
