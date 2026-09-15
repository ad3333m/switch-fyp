import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @EnvironmentObject var addonManager: AddonManager
    @State private var addingSample = false
    @State private var sampleAdded = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Welcome to Filmo")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("A movie and TV browser with an Apple TV-style look, built around the open Stremio addon protocol.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.top, 20)

                    infoRow(
                        icon: "sparkles.tv",
                        title: "Browse everything",
                        body: "The Watch Now and Search tabs show trending, popular, and top-rated movies and TV shows by default - no setup needed."
                    )

                    infoRow(
                        icon: "puzzlepiece.extension.fill",
                        title: "Addons provide the sources",
                        body: "Filmo doesn't host or stream anything itself. To actually play a title, add a Stremio addon - a service that resolves streams for titles - in the Addons tab, by pasting its manifest.json URL."
                    )

                    infoRow(
                        icon: "play.circle.fill",
                        title: "One tap to play",
                        body: "Open any title and tap Play. Filmo checks every addon you've installed and plays the first direct link it finds - or shows you all of them under \"Available sources\"."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Don't have an addon yet?")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("You can start with a small sample addon (public-domain classic films, streamed from the Internet Archive) just to see how it works, and add real addons later in the Addons tab.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Button {
                            Task { await addSample() }
                        } label: {
                            HStack {
                                if addingSample {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: sampleAdded ? "checkmark" : "plus")
                                    Text(sampleAdded ? "Sample addon added" : "Add sample addon")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .glassCapsule()
                        }
                        .disabled(addingSample || sampleAdded)
                    }
                    .padding(16)
                    .glassCard()

                    Button {
                        onFinish()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Get Started").fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .foregroundColor(.black)
                        .background(Color.white, in: Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
    }

    private func infoRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(body)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private func addSample() async {
        addingSample = true
        defer { addingSample = false }
        try? await addonManager.add(urlString: AddonManager.sampleAddonURLString)
        sampleAdded = true
    }
}
