import Foundation

@MainActor
final class AddonManager: ObservableObject {
    @Published private(set) var addons: [Addon] = []

    private let defaultsKey = "stremio.installedAddonURLs"

    init() {
        Task { await loadPersisted() }
    }

    private func loadPersisted() async {
        let urls = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            if let manifest = try? await StremioAPI.fetchManifest(url: url) {
                addons.append(Addon(manifestURL: url, manifest: manifest))
            }
        }
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
