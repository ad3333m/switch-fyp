import SwiftUI

struct PosterCardView: View {
    let item: MetaPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: item.poster ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(2 / 3, contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Image(systemName: "film")
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
            }
            .frame(width: 150, height: 225)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 8, y: 5)

            Text(item.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
        }
    }
}
