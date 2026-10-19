import SwiftUI

struct ScanDetailView: View {
    let documentID: UUID

    @Environment(ScanStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var captureRequest: CaptureSource?
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var isConfirmingDelete = false
    @State private var pagePendingDeletion: ScanPage?
    @State private var shareItem: ShareItem?
    @State private var isExporting = false
    @State private var isShowingText = false
    @State private var viewerPage: PageSelection?

    private struct PageSelection: Identifiable {
        let pageID: UUID
        var id: UUID { pageID }
    }

    var body: some View {
        if let document = store.document(id: documentID) {
            pageGrid(for: document)
                .navigationTitle(document.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent(for: document) }
                .safeAreaInset(edge: .top) {
                    if store.isRecognizing(documentID) {
                        recognitionBanner
                    }
                }
                .pageCapture($captureRequest) { images in
                    Task { await store.addPages(images, to: documentID) }
                }
                .alert("เปลี่ยนชื่อเอกสาร", isPresented: $isRenaming) {
                    TextField("ชื่อเอกสาร", text: $renameText)
                    Button("บันทึก") {
                        store.rename(documentID, to: renameText)
                    }
                    Button("ยกเลิก", role: .cancel) {}
                }
                .confirmationDialog("ลบเอกสารนี้?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                    Button("ลบเอกสาร", role: .destructive) {
                        dismiss()
                        store.deleteDocument(documentID)
                    }
                } message: {
                    Text("ทุกหน้าในเอกสารนี้จะถูกลบถาวรและกู้คืนไม่ได้")
                }
                .confirmationDialog(
                    "ลบหน้านี้?",
                    isPresented: $pagePendingDeletion.isPresent(),
                    titleVisibility: .visible,
                    presenting: pagePendingDeletion
                ) { page in
                    Button("ลบหน้า", role: .destructive) {
                        store.deletePage(page.id, from: documentID)
                    }
                }
                .sheet(item: $shareItem) { item in
                    ActivityView(items: item.items, onComplete: { shareItem = nil })
                        .presentationDetents([.medium, .large])
                        .ignoresSafeArea()
                }
                .sheet(isPresented: $isShowingText) {
                    RecognizedTextView(documentID: documentID)
                }
                .fullScreenCover(item: $viewerPage) { selection in
                    PageViewerView(documentID: documentID, initialPageID: selection.pageID)
                }
        } else {
            ContentUnavailableView("ไม่พบเอกสาร", systemImage: "doc.questionmark")
        }
    }

    private func pageGrid(for document: ScanDocument) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 20) {
                ForEach(Array(document.pages.enumerated()), id: \.element.id) { index, page in
                    Button {
                        viewerPage = PageSelection(pageID: page.id)
                    } label: {
                        PageCell(url: store.imageURL(for: page, in: documentID), number: index + 1)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("คัดลอกข้อความหน้านี้", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = page.text
                        }
                        .disabled(page.text.isEmpty)
                        Button("ลบหน้านี้", systemImage: "trash", role: .destructive) {
                            pagePendingDeletion = page
                        }
                        .disabled(document.pages.count <= 1)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ToolbarContentBuilder
    private func toolbarContent(for document: ScanDocument) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await sharePDF() }
            } label: {
                if isExporting {
                    ProgressView()
                } else {
                    Label("แชร์ PDF", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(isExporting)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("เปลี่ยนชื่อ", systemImage: "pencil") {
                    renameText = document.title
                    isRenaming = true
                }
                Section("เพิ่มหน้า") {
                    Button("สแกนเพิ่ม", systemImage: "doc.viewfinder") {
                        captureRequest = .camera
                    }
                    Button("นำเข้าจากรูปภาพ", systemImage: "photo.on.rectangle") {
                        captureRequest = .photos
                    }
                }
                Section("ข้อความ (OCR)") {
                    Button("ดูข้อความ", systemImage: "text.viewfinder") {
                        isShowingText = true
                    }
                    Button("คัดลอกข้อความทั้งหมด", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = document.fullText
                    }
                    .disabled(document.fullText.isEmpty)
                    Button("แชร์เป็นข้อความ", systemImage: "text.alignleft") {
                        shareItem = ShareItem(items: [document.fullText])
                    }
                    .disabled(document.fullText.isEmpty)
                }
                Button("ลบเอกสาร", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            } label: {
                Label("ตัวเลือก", systemImage: "ellipsis.circle")
            }
        }
    }

    private var recognitionBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("กำลังอ่านข้อความในเอกสาร…")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @MainActor
    private func sharePDF() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try await store.exportPDF(for: documentID)
            shareItem = ShareItem(items: [url])
        } catch {
            store.errorMessage = "สร้างไฟล์ PDF ไม่สำเร็จ: \(error.localizedDescription)"
        }
    }
}
