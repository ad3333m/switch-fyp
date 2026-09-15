import SwiftUI

@main
struct FilmoApp: App {
    @StateObject private var addonManager = AddonManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(addonManager)
                .preferredColorScheme(.dark)
        }
    }
}
