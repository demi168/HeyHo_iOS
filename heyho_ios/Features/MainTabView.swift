import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            FriendsView()
                .tabItem { Label("友だち", systemImage: "person.2") }
                .tag(0)
            InboxView()
                .tabItem { Label("受信", systemImage: "tray") }
                .tag(1)
            ProfileView()
                .tabItem { Label("プロフィール", systemImage: "person.circle") }
                .tag(2)
        }
    }
}
