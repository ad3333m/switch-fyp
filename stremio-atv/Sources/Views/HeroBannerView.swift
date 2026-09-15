import SwiftUI

struct HeroBannerView: View {
    let items: [SelectedItem]
    let onPlay: (SelectedItem) -> Void
    let onInfo: (SelectedItem) -> Void

    @State private var index = 0
    private let timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    AsyncImage(url: URL(string: item.preview.background ?? item.preview.poster ?? "")) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.white.opacity(0.05)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(i == index ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6), value: index)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.55), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if let current = items[safe: index] {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(current.preview.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(radius: 8)
                            .lineLimit(2)

                        if let desc = current.preview.description {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(2)
                                .frame(maxWidth: geo.size.width * 0.85, alignment: .leading)
                        }

                        HStack(spacing: 14) {
                            Button {
                                onPlay(current)
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .font(.headline)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }

                            Button {
                                onInfo(current)
                            } label: {
                                Label("Info", systemImage: "info.circle")
                                    .font(.headline)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.18))
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 10)
                }
            }
        }
        .frame(height: 460)
        .onReceive(timer) { _ in
            guard !items.isEmpty else { return }
            index = (index + 1) % items.count
        }
        .onChange(of: items.count) { _ in index = 0 }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
