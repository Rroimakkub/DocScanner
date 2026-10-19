import SwiftUI

struct ScanRowView: View {
    let document: ScanDocument
    let coverURL: URL?
    let isRecognizing: Bool

    var body: some View {
        HStack(spacing: 12) {
            cover
                .frame(width: 52, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(document.createdAt, format: .dateTime.day().month().year())
                    Text("·")
                    Text("\(document.pages.count) หน้า")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if isRecognizing {
                    Label("กำลังอ่านข้อความ…", systemImage: "text.viewfinder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var cover: some View {
        if let coverURL {
            PageThumbnail(url: coverURL, maxPixelSize: 200)
        } else {
            Color(uiColor: .secondarySystemBackground)
        }
    }
}
