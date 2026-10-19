import SwiftUI

/// A page image decoded at a small size, loaded off the main thread.
struct PageThumbnail: View {
    let url: URL
    var maxPixelSize = 400
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            image = await ImageLoader.thumbnail(for: url, maxPixelSize: maxPixelSize)
        }
    }
}

/// A page in the document's grid: the page image with its number underneath.
struct PageCell: View {
    let url: URL
    let number: Int

    var body: some View {
        VStack(spacing: 6) {
            Color(uiColor: .secondarySystemGroupedBackground)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    PageThumbnail(url: url, maxPixelSize: 600, contentMode: .fit)
                        .padding(4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            Text("\(number)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
