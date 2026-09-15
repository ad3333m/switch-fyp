import Foundation

struct MetaPreview: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let description: String?
}

struct MetaDetail: Codable, Hashable {
    let id: String
    let type: String
    let name: String
    let poster: String?
    let background: String?
    let description: String?
}

/// A title selected for the detail screen. Streams are resolved by
/// querying every installed addon for `preview.id`/`preview.type` (the
/// standard Stremio convention), regardless of which source (TMDb or an
/// addon's own catalog) the preview came from.
struct SelectedItem: Identifiable, Hashable {
    let preview: MetaPreview
    var id: String { preview.type + ":" + preview.id }
}
