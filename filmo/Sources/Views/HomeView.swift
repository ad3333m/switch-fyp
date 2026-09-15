import SwiftUI

struct HomeView: View {
    @EnvironmentObject var addonManager: AddonManager
    @State private var selection: SelectedItem?
    @State private var heroPlayable: PlayableURL?
    @State private var heroError: String?

    private struct AddonShelf: Identifiable {
        let id: String
        let base: URL
        let catalog: CatalogDef
        let title: String
    }

    private var addonShelves: [AddonShelf] {
        addonManager.addons.flatMap { addon -> [AddonShelf] in
            let base = StremioAPI.base(from: addon.manifestURL)
            return (addon.manifest.catalogs ?? []).map { catalog in
                AddonShelf(
                    id: addon.id + catalog.type + catalog.id,
                    base: base,
                    catalog: catalog,
                    title: catalog.name ?? catalog.id
                )
            }
        }
    }

    // TMDb-backed shelves populate the home screen by default (movies and
    // series alike), independent of which addons are installed. Addons are
    // only queried for streams when you open a title.
    @State private var trending: [MetaPreview] = []
    @State private var popularMovies: [MetaPreview] = []
    @State private var popularSeries: [MetaPreview] = []
    @State private var topRatedMovies: [MetaPreview] = []
    @State private var topRatedSeries: [MetaPreview] = []
    @State private var loadedTMDb = false

    private var heroItems: [SelectedItem] {
        trending.prefix(5).map { SelectedItem(preview: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !heroItems.isEmpty {
                        HeroBannerView(
                            items: heroItems,
                            onPlay: { playFirstStream(for: $0) },
                            onInfo: { selection = $0 }
                        )
                    }

                    LazyVStack(alignment: .leading, spacing: 28) {
                        StaticShelfRowView(title: "Trending Now", items: trending) { selection = $0 }
                        StaticShelfRowView(title: "Popular Movies", items: popularMovies) { selection = $0 }
                        StaticShelfRowView(title: "Popular TV Shows", items: popularSeries) { selection = $0 }
                        StaticShelfRowView(title: "Top Rated Movies", items: topRatedMovies) { selection = $0 }
                        StaticShelfRowView(title: "Top Rated TV Shows", items: topRatedSeries) { selection = $0 }

                        ForEach(addonShelves) { shelf in
                            ShelfRowView(shelfBase: shelf.base, catalog: shelf.catalog, title: shelf.title) { item in
                                selection = item
                            }
                        }
                    }
                    .padding(.top, heroItems.isEmpty ? 12 : 0)

                    if !loadedTMDb || (trending.isEmpty && addonShelves.isEmpty) {
                        emptyState
                    }
                }
            }
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Watch Now").font(.headline).foregroundColor(.white)
                }
            }
            .navigationDestination(item: $selection) { sel in
                DetailView(preview: sel.preview)
            }
            .fullScreenCover(item: $heroPlayable) { p in
                PlayerView(playable: p)
            }
            .alert("Can't play this title", isPresented: Binding(get: { heroError != nil }, set: { if !$0 { heroError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(heroError ?? "")
            }
            .task { await loadTMDb() }
        }
    }

    private func loadTMDb() async {
        guard !loadedTMDb else { return }
        loadedTMDb = true
        async let t = TMDbAPI.fetchTrending()
        async let pm = TMDbAPI.popularMovies()
        async let ps = TMDbAPI.popularSeries()
        async let tm = TMDbAPI.topRatedMovies()
        async let ts = TMDbAPI.topRatedSeries()
        trending = await t
        popularMovies = await pm
        popularSeries = await ps
        topRatedMovies = await tm
        topRatedSeries = await ts
    }

    private func playFirstStream(for item: SelectedItem) {
        Task {
            guard let url = await AddonManager.firstPlayableStream(
                addons: addonManager.addons,
                type: item.preview.type,
                id: item.preview.id
            ) else {
                heroError = "No direct playable stream was found for this title from your installed addons."
                return
            }
            heroPlayable = PlayableURL(url: url)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: TMDbSecrets.apiKey.isEmpty ? "key.slash" : "puzzlepiece.extension")
                .font(.system(size: 44))
                .foregroundColor(.gray)
            Text(TMDbSecrets.apiKey.isEmpty ? "No TMDb API key configured" : "No addons yet")
                .font(.headline)
                .foregroundColor(.white)
            Text(TMDbSecrets.apiKey.isEmpty
                 ? "The home screen catalog needs a TMDb API key to populate. Add addon(s) in the Addons tab to browse and play their own catalogs in the meantime."
                 : "Add a Stremio addon manifest URL in the Addons tab so titles have somewhere to play from.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}
