import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Watch Now", systemImage: "play.tv") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            AddonsSettingsView()
                .tabItem { Label("Addons", systemImage: "puzzlepiece.extension") }
        }
        .tint(.white)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
