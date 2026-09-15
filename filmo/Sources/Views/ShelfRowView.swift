import SwiftUI

struct ShelfRowView: View {
    let shelfBase: URL
    let catalog: CatalogDef
    let title: String
    let onSelect: (SelectedItem) -> Void

    @State private var items: [MetaPreview] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        Button {
                            onSelect(SelectedItem(base: shelfBase, preview: item))
                        } label: {
                            PosterCardView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            items = (try? await StremioAPI.fetchCatalog(base: shelfBase, type: catalog.type, catalogId: catalog.id)) ?? []
        }
    }
}
