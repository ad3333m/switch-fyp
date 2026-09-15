import SwiftUI

struct SearchView: View {
    @EnvironmentObject var addonManager: AddonManager
    @State private var query = ""
    @State private var results: [SelectedItem] = []
    @State private var selection: SelectedItem?
    @State private var searching = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if searching {
                    ProgressView().padding(.top, 60).tint(.white)
                } else if results.isEmpty {
                    Text(query.isEmpty ? "Search movies, TV shows, and your installed addons." : "No results.")
                        .foregroundColor(.gray)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(results) { item in
                            Button {
                                selection = item
                            } label: {
                                PosterCardView(item: item.preview)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .background(AppBackground())
            .navigationTitle("Search")
            .searchable(text: $query)
            .onSubmit(of: .search) { Task { await performSearch() } }
            .navigationDestination(item: $selection) { sel in
                DetailView(preview: sel.preview)
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        searching = true
        defer { searching = false }

        async let tmdbResults = TMDbAPI.search(query: trimmed)

        var addonResults: [MetaPreview] = []
        for addon in addonManager.addons {
            let base = StremioAPI.base(from: addon.manifestURL)
            for catalog in addon.manifest.catalogs ?? [] {
                if let metas = try? await StremioAPI.fetchCatalog(base: base, type: catalog.type, catalogId: catalog.id, search: trimmed) {
                    addonResults.append(contentsOf: metas)
                }
            }
        }

        var seen = Set<String>()
        var combined: [SelectedItem] = []
        for preview in (await tmdbResults) + addonResults {
            let key = preview.type + ":" + preview.id
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            combined.append(SelectedItem(preview: preview))
        }
        results = combined
    }
}
