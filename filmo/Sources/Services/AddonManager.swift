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
}
