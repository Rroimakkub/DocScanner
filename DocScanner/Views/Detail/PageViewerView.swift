import SwiftUI

/// Full-screen pager over a document's pages, with pinch and double-tap zoom.
struct PageViewerView: View {
    let documentID: UUID

    @Environment(ScanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID

    init(documentID: UUID, initialPageID: UUID) {
        self.documentID = documentID
        _selection = State(initialValue: initialPageID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let document = store.document(id: documentID) {
                    TabView(selection: $selection) {
                        ForEach(document.pages) { page in
                            PageImageView(url: store.imageURL(for: page, in: documentID))
                                .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .navigationTitle(title(in: document))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            let text = currentPage(in: document)?.text ?? ""
                            Button("คัดลอกข้อความหน้านี้", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = text
                            }
                            .disabled(text.isEmpty)
                        }
                    }
                } else {
                    Color.clear
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
    }

    private func currentPage(in document: ScanDocument) -> ScanPage? {
        document.pages.first { $0.id == selection }
    }

    private func title(in document: ScanDocument) -> String {
        let index = document.pages.firstIndex { $0.id == selection } ?? 0
        return "หน้า \(index + 1) จาก \(document.pages.count)"
    }
}

private struct PageImageView: View {
    let url: URL

    @State private var image: UIImage?
    @State private var didFailToLoad = false

    var body: some View {
        ZStack {
            if let image {
                ZoomableImageView(image: image)
            } else if didFailToLoad {
                Label("โหลดภาพไม่สำเร็จ", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.white)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task(id: url) {
            didFailToLoad = false
            image = await ImageLoader.fullImage(at: url)
            didFailToLoad = image == nil
        }
    }
}
