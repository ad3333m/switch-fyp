import SwiftUI

@main
struct FilmoApp: App {
    @StateObject private var addonManager = AddonManager()
    @AppStorage("filmo.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootTabView()
                } else {
                    OnboardingView { hasCompletedOnboarding = true }
                }
            }
            .environmentObject(addonManager)
            .preferredColorScheme(.dark)
        }
    }
}
