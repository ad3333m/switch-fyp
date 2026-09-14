import SwiftUI

@main
struct StremioATVApp: App {
    @StateObject private var addonManager = AddonManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(addonManager)
                .preferredColorScheme(.dark)
        }
    }
}
