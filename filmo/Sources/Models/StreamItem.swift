import Foundation

// Only direct HTTP(S) media streams are supported here. Torrent/magnet-only
// entries (infoHash with no url) are intentionally left unplayable - this
// app does not embed a torrent/BitTorrent client.
struct StreamItem: Codable, Identifiable, Hashable {
    var id: String { (url ?? infoHash ?? title ?? name ?? UUID().uuidString) }
    let url: String?
    let title: String?
    let name: String?
    let infoHash: String?

    var isPlayable: Bool {
        guard let url, let scheme = URL(string: url)?.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }
}
