import SwiftUI

struct DetailView: View {
    let preview: MetaPreview

    @EnvironmentObject var addonManager: AddonManager

    @State private var sources: [AddonManager.SourceStream] = []
    @State private var loadingStreams = false
    @State private var playable: PlayableURL?
    @State private var errorMessage: String?

    @State private var extra: TMDbAPI.ExtraDetails?
    @State private var appeared = false

    private var groupedSources: [(addonName: String, streams: [StreamItem])] {
        let grouped = Dictionary(grouping: sources, by: \.addonName)
        return grouped
            .map { (addonName: $0.key, streams: $0.value.map(\.stream)) }
            .sorted { $0.addonName < $1.addonName }
    }

    var body: some View {
        ScrollView {
            header

            VStack(alignment: .leading, spacing: 18) {
                metaRow
                    .revealOnAppear(appeared, delay: 0.05)

                if !(extra?.genres.isEmpty ?? true) {
                    genrePills
                        .revealOnAppear(appeared, delay: 0.1)
                }

                if let desc = preview.description, !desc.isEmpty {
                    Text(desc)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(3)
                        .revealOnAppear(appeared, delay: 0.15)
                }

                if let cast = extra?.cast, !cast.isEmpty {
                    castSection(cast)
                        .revealOnAppear(appeared, delay: 0.2)
                }

                sourcesSection
                    .revealOnAppear(appeared, delay: 0.25)
            }
            .padding(20)
        }
        .background(AppBackground())
        .task {
            await load()
            withAnimation { appeared = true }
        }
        .fullScreenCover(item: $playable) { p in
            PlayerView(playable: p)
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: preview.background ?? preview.poster ?? "")) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(height: 360)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.4), .black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)

            Text(preview.name)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .shadow(radius: 8)
                .padding(20)
        }
    }

    // MARK: - Rating / age rating / runtime row

    private var metaRow: some View {
        HStack(spacing: 10) {
            if let rating = extra?.rating, rating > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassPill()
            }

            if let certification = extra?.certification, !certification.isEmpty {
                Text(certification)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassPill(cornerRadius: 6)
            }

            if let minutes = extra?.runtimeMinutes, minutes > 0 {
                Text(runtimeLabel(minutes))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassPill()
            }

            Spacer()
        }
    }

    private func runtimeLabel(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    private var genrePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(extra?.genres ?? [], id: \.self) { genre in
                    Text(genre)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassPill()
                }
            }
        }
    }

    private func castSection(_ cast: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cast")
                .font(.headline)
                .foregroundColor(.white)
            Text(cast.joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
        }
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available sources")
                .font(.headline)
                .foregroundColor(.white)

            if loadingStreams {
                ProgressView().tint(.white)
            } else if sources.isEmpty {
                Text(addonManager.addons.isEmpty
                     ? "No addons installed. Add one in the Addons tab to find sources for this title."
                     : "No streams found for this title from any of your installed addons.")
                    .foregroundColor(.gray)
            } else {
                ForEach(groupedSources, id: \.addonName) { group in
                    Text(group.addonName)
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                    ForEach(group.streams) { stream in
                        streamRow(stream)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
    }

    private func streamRow(_ stream: StreamItem) -> some View {
        Button {
            openStream(stream)
        } label: {
            HStack {
                Image(systemName: stream.isPlayable ? "play.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(stream.isPlayable ? .white : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.title ?? stream.name ?? "Stream")
                        .foregroundColor(.white)
                    if !stream.isPlayable {
                        Text("Unsupported stream type (not a direct link)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
            }
            .padding(14)
            .glassCard(cornerRadius: 14)
        }
    }

    private func load() async {
        loadingStreams = true
        async let sourcesTask = AddonManager.allStreams(addons: addonManager.addons, type: preview.type, id: preview.id)
        async let extraTask = TMDbAPI.fetchExtraDetails(imdbId: preview.id, type: preview.type)
        sources = await sourcesTask
        extra = await extraTask
        loadingStreams = false
    }

    private func openStream(_ stream: StreamItem) {
        guard stream.isPlayable, let urlString = stream.url, let url = URL(string: urlString) else {
            errorMessage = "This stream isn't a direct playable link (e.g. torrent/magnet), which this app doesn't support."
            return
        }
        errorMessage = nil
        playable = PlayableURL(url: url)
    }
}
