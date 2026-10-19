import SwiftUI

/// The OCR text of a document, page by page, selectable and copyable.
struct RecognizedTextView: View {
    let documentID: UUID

    @Environment(ScanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        let document = store.document(id: documentID)
        let fullText = document?.fullText ?? ""

        NavigationStack {
            Group {
                if let document, !fullText.isEmpty {
                    textList(for: document)
                } else if store.isRecognizing(documentID) {
                    ProgressView("กำลังอ่านข้อความ…")
                } else {
                    ContentUnavailableView(
                        "ไม่พบข้อความ",
                        systemImage: "text.magnifyingglass",
                        description: Text("ไม่พบข้อความที่อ่านได้ในเอกสารนี้")
                    )
                }
            }
            .navigationTitle("ข้อความในเอกสาร")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(didCopy ? "คัดลอกแล้ว" : "คัดลอกทั้งหมด") {
                        UIPasteboard.general.string = fullText
                        didCopy = true
                    }
                    .disabled(fullText.isEmpty)
                }
            }
        }
    }

    private func textList(for document: ScanDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(document.pages.enumerated()), id: \.element.id) { index, page in
                    if !page.text.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("หน้า \(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(page.text)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
