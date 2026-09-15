import SwiftUI
import AVKit

struct PlayableURL: Identifiable, Hashable {
    let id = UUID()
    let url: URL
}

struct PlayerView: View {
    let playable: PlayableURL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(playable: PlayableURL) {
        self.playable = playable
        _player = State(initialValue: AVPlayer(url: playable.url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear { player.play() }
            .onDisappear { player.pause() }
            .overlay(alignment: .topTrailing) {
                Button {
                    player.pause()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.85))
                        .padding()
                }
            }
    }
}
