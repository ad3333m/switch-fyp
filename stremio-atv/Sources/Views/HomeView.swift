import SwiftUI

struct HomeView: View {
    @EnvironmentObject var addonManager: AddonManager
    @State private var selection: SelectedItem?

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

    var body: some View {
        NavigationStack {
            ScrollView {
                if shelves.isEmpty {
                    emptyState
                } else {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(shelves) { shelf in
                            ShelfRowView(shelfBase: shelf.base, catalog: shelf.catalog, title: shelf.title) { item in
                                selection = item
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Watch Now")
            .navigationDestination(item: $selection) { sel in
                DetailView(base: sel.base, preview: sel.preview)
            }
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
