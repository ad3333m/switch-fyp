import SwiftUI

/// A shelf whose items are already fetched (e.g. from TMDb), as opposed to
/// ShelfRowView which lazily fetches an addon's catalog on appear.
struct StaticShelfRowView: View {
    let title: String
    let items: [MetaPreview]
    let onSelect: (SelectedItem) -> Void

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(items) { item in
                            Button {
                                onSelect(SelectedItem(preview: item))
                            } label: {
                                PosterCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
