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

struct SelectedItem: Identifiable, Hashable {
    let base: URL
    let preview: MetaPreview
    var id: String { base.absoluteString + "|" + preview.id }
}
