import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @EnvironmentObject var addonManager: AddonManager
    @State private var addingSample = false
    @State private var sampleAdded = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white)
                        Text("Welcome to Filmo")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("A movie and TV browser built around the open Stremio addon protocol.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .leading, spacing: 14) {
                        infoRow(
                            icon: "sparkles.tv",
                            title: "Browse everything",
                            body: "Trending, popular, and top-rated movies and TV shows, by default."
                        )
                        infoRow(
                            icon: "puzzlepiece.extension.fill",
                            title: "Addons provide the sources",
                            body: "Filmo doesn't host anything itself. Add a Stremio addon's manifest.json URL in the Addons tab to get playable sources."
                        )
                        infoRow(
                            icon: "play.circle.fill",
                            title: "One tap to play",
                            body: "Tap Play - Filmo checks every addon you've installed and plays the first source it finds."
                        )
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Don't have an addon yet?")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Try a small sample (public-domain films from the Internet Archive) to see how it works.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))

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
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .glassCapsule()
                        }
                        .disabled(addingSample || sampleAdded)
                    }
                    .padding(14)
                    .glassCard()

                    Spacer(minLength: 12)

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
                }
                .padding(.horizontal, 20)
                .padding(.top, geo.safeAreaInsets.top + 16)
                .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }

    private func infoRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(body)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
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
