import Foundation

struct CatalogDef: Codable, Hashable {
    let type: String
    let id: String
    let name: String?
}

struct Manifest: Codable, Hashable {
    let id: String
    let name: String
    let version: String?
    let description: String?
    let types: [String]?
    let catalogs: [CatalogDef]?
}

struct Addon: Identifiable, Hashable {
    var id: String { manifestURL.absoluteString }
    let manifestURL: URL
    let manifest: Manifest
}
