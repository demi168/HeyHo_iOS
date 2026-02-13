import SwiftUI

struct RootView: View {
    @StateObject private var authState = AuthState()

    var body: some View {
        Group {
            if authState.isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authState.isAuthenticated {
                MainTabView()
            } else {
                SignInView()
            }
        }
        .environmentObject(authState)
    }
}
