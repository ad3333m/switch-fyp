import Foundation

@MainActor
final class AddonManager: ObservableObject {
    @Published private(set) var addons: [Addon] = []

    private let defaultsKey = "stremio.installedAddonURLs"
    private let seededDefaultKey = "stremio.hasSeededDefaultAddon"

    /// A small curated catalog of confirmed US public-domain films, streamed
    /// from the Internet Archive, installed automatically on first launch so
    /// there's real, legally playable content out of the box. Users can
    /// remove it and add their own addons at any time in the Addons tab.
    private let defaultAddonURLString = "https://ad3333m.github.io/switch-fyp/stremio-addon/manifest.json"

    init() {
        Task { await loadPersisted() }
    }

    private func loadPersisted() async {
        var urls = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []

        if urls.isEmpty && !UserDefaults.standard.bool(forKey: seededDefaultKey) {
            urls = [defaultAddonURLString]
        }
        UserDefaults.standard.set(true, forKey: seededDefaultKey)

        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            if let manifest = try? await StremioAPI.fetchManifest(url: url) {
                addons.append(Addon(manifestURL: url, manifest: manifest))
            }
        }
        persist()
    }

    func add(urlString: String) async throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            throw StremioAPIError.badURL
        }
        guard !addons.contains(where: { $0.manifestURL == url }) else { return }
        let manifest = try await StremioAPI.fetchManifest(url: url)
        addons.append(Addon(manifestURL: url, manifest: manifest))
        persist()
    }

    func remove(at offsets: IndexSet) {
        addons.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        let urls = addons.map { $0.manifestURL.absoluteString }
        UserDefaults.standard.set(urls, forKey: defaultsKey)
    }

    /// One stream option, tagged with which installed addon it came from -
    /// used to show "Available sources" grouped by addon.
    struct SourceStream: Identifiable, Hashable {
        let addonName: String
        let stream: StreamItem
        var id: String { addonName + "|" + stream.id }
    }

    /// Queries every installed addon's stream endpoint for the given
    /// (type, id) - typically an IMDb id - concurrently, and returns every
    /// result found, tagged by which addon it came from. This is how "every
    /// addon" gets a chance to offer a source for a title, regardless of
    /// which catalog (TMDb or an addon's own) the title was browsed from.
    static func allStreams(addons: [Addon], type: String, id: String) async -> [SourceStream] {
        await withTaskGroup(of: [SourceStream].self) { group in
            for addon in addons {
                group.addTask {
                    let base = StremioAPI.base(from: addon.manifestURL)
                    let streams = (try? await StremioAPI.fetchStreams(base: base, type: type, id: id)) ?? []
                    return streams.map { SourceStream(addonName: addon.manifest.name, stream: $0) }
                }
            }
            var results: [SourceStream] = []
            for await batch in group {
                results.append(contentsOf: batch)
            }
            return results
        }
    }

    static func firstPlayableStream(addons: [Addon], type: String, id: String) async -> URL? {
        let all = await allStreams(addons: addons, type: type, id: id)
        guard let playable = all.first(where: { $0.stream.isPlayable }),
              let urlString = playable.stream.url else { return nil }
        return URL(string: urlString)
    }
}
