import SwiftUI

struct HomeView: View {
    @EnvironmentObject var addonManager: AddonManager
    @State private var selection: SelectedItem?
    @State private var heroPlayable: PlayableURL?
    @State private var heroError: String?

    private struct Shelf: Identifiable {
        let id: String
        let base: URL
        let catalog: CatalogDef
        let title: String
    }

    private var shelves: [Shelf] {
        addonManager.addons.flatMap { addon -> [Shelf] in
            let base = StremioAPI.base(from: addon.manifestURL)
            return (addon.manifest.catalogs ?? []).map { catalog in
                Shelf(
                    id: addon.id + catalog.type + catalog.id,
                    base: base,
                    catalog: catalog,
                    title: catalog.name ?? catalog.id
                )
            }
        }
    }

    @State private var heroItems: [SelectedItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if shelves.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 28) {
                        if !heroItems.isEmpty {
                            HeroBannerView(
                                items: heroItems,
                                onPlay: { playFirstStream(for: $0) },
                                onInfo: { selection = $0 }
                            )
                        }

                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(shelves) { shelf in
                                ShelfRowView(shelfBase: shelf.base, catalog: shelf.catalog, title: shelf.title) { item in
                                    selection = item
                                }
                            }
                        }
                        .padding(.top, heroItems.isEmpty ? 12 : 0)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Watch Now").font(.headline).foregroundColor(.white)
                }
            }
            .navigationDestination(item: $selection) { sel in
                DetailView(base: sel.base, preview: sel.preview)
            }
            .fullScreenCover(item: $heroPlayable) { p in
                PlayerView(playable: p)
            }
            .alert("Can't play this title", isPresented: Binding(get: { heroError != nil }, set: { if !$0 { heroError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(heroError ?? "")
            }
            .task { await loadHero() }
            .onChange(of: shelves.map(\.id)) { _ in Task { await loadHero() } }
        }
    }

    private func loadHero() async {
        guard let first = shelves.first else {
            heroItems = []
            return
        }
        let metas = (try? await StremioAPI.fetchCatalog(base: first.base, type: first.catalog.type, catalogId: first.catalog.id)) ?? []
        heroItems = metas.prefix(5).map { SelectedItem(base: first.base, preview: $0) }
    }

    private func playFirstStream(for item: SelectedItem) {
        Task {
            let streams = (try? await StremioAPI.fetchStreams(base: item.base, type: item.preview.type, id: item.preview.id)) ?? []
            guard let playableStream = streams.first(where: { $0.isPlayable }),
                  let urlString = playableStream.url,
                  let url = URL(string: urlString) else {
                heroError = "No direct playable stream was found for this title from your installed addons."
                return
            }
            heroPlayable = PlayableURL(url: url)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 44))
                .foregroundColor(.gray)
            Text("No addons yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Add a Stremio addon manifest URL in the Addons tab to get started.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 100)
        .frame(maxWidth: .infinity)
    }
}
