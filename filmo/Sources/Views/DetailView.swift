import SwiftUI

struct DetailView: View {
    let base: URL
    let preview: MetaPreview

    @State private var meta: MetaDetail?
    @State private var streams: [StreamItem] = []
    @State private var loadingStreams = false
    @State private var playable: PlayableURL?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            header

            VStack(alignment: .leading, spacing: 16) {
                if let desc = meta?.description ?? preview.description, !desc.isEmpty {
                    Text(desc)
                        .foregroundColor(.white.opacity(0.8))
                }

                Text("Streams")
                    .font(.headline)
                    .foregroundColor(.white)

                if loadingStreams {
                    ProgressView().tint(.white)
                } else if streams.isEmpty {
                    Text("No streams found for this title from your installed addons.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(streams) { stream in
                        streamRow(stream)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .task { await load() }
        .fullScreenCover(item: $playable) { p in
            PlayerView(playable: p)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: preview.background ?? preview.poster ?? "")) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(height: 320)
            .clipped()

            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)

            Text(preview.name)
                .font(.largeTitle.bold())
                .foregroundColor(.white)
                .padding()
                .shadow(radius: 6)
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
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
        }
    }

    private func load() async {
        loadingStreams = true
        async let metaResult: MetaDetail? = try? StremioAPI.fetchMeta(base: base, type: preview.type, id: preview.id)
        async let streamResult: [StreamItem] = (try? StremioAPI.fetchStreams(base: base, type: preview.type, id: preview.id)) ?? []
        meta = await metaResult
        streams = await streamResult
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
