import Foundation

private struct CatalogResponse: Codable { let metas: [MetaPreview]? }
private struct MetaResponse: Codable { let meta: MetaDetail }
private struct StreamResponse: Codable { let streams: [StreamItem]? }

enum StremioAPIError: Error {
    case badURL
}

enum StremioAPI {

    /// The addon's base URL (everything before "manifest.json").
    static func base(from manifestURL: URL) -> URL {
        manifestURL.deletingLastPathComponent()
    }

    private static func url(base: URL, path: String) throws -> URL {
        var baseString = base.absoluteString
        if !baseString.hasSuffix("/") { baseString += "/" }
        guard let url = URL(string: baseString + path) else { throw StremioAPIError.badURL }
        return url
    }

    private static func encode(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    }

    static func fetchManifest(url: URL) async throws -> Manifest {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Manifest.self, from: data)
    }

    static func fetchCatalog(base: URL, type: String, catalogId: String, search: String? = nil) async throws -> [MetaPreview] {
        var path = "catalog/\(encode(type))/\(encode(catalogId))"
        if let search, !search.trimmingCharacters(in: .whitespaces).isEmpty {
            let encodedQuery = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
            path += "/search=\(encodedQuery)"
        }
        path += ".json"
        let requestURL = try url(base: base, path: path)
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        let decoded = try JSONDecoder().decode(CatalogResponse.self, from: data)
        return decoded.metas ?? []
    }

    static func fetchMeta(base: URL, type: String, id: String) async throws -> MetaDetail {
        let requestURL = try url(base: base, path: "meta/\(encode(type))/\(encode(id)).json")
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        let decoded = try JSONDecoder().decode(MetaResponse.self, from: data)
        return decoded.meta
    }

    static func fetchStreams(base: URL, type: String, id: String) async throws -> [StreamItem] {
        let requestURL = try url(base: base, path: "stream/\(encode(type))/\(encode(id)).json")
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        let decoded = try JSONDecoder().decode(StreamResponse.self, from: data)
        return decoded.streams ?? []
    }
}
