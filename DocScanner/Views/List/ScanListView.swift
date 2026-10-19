import SwiftUI

struct ScanListView: View {
    @Environment(ScanStore.self) private var store

    @State private var path: [UUID] = []
    @State private var searchText = ""
    @State private var captureRequest: CaptureSource?
    @State private var documentPendingDeletion: ScanDocument?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("เอกสาร")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .navigationDestination(for: UUID.self) { documentID in
                ScanDetailView(documentID: documentID)
            }
        }
        .pageCapture($captureRequest) { pages in
            Task { await saveNewDocument(pages) }
        }
        .overlay {
            if store.isSaving {
                ProgressOverlay(message: "กำลังบันทึก…")
            }
        }
        .alert(
            "เกิดข้อผิดพลาด",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.errorMessage = nil
                    }
                }
            )
        ) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var filteredDocuments: [ScanDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.documents }
        return store.documents.filter { document in
            document.title.localizedStandardContains(query) || document.fullText.localizedStandardContains(query)
        }
    }

    private var documentList: some View {
        List {
            ForEach(filteredDocuments) { document in
                NavigationLink(value: document.id) {
                    ScanRowView(
                        document: document,
                        coverURL: store.coverImageURL(for: document),
                        isRecognizing: store.isRecognizing(document.id)
                    )
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        documentPendingDeletion = document
                    } label: {
                        Label("ลบ", systemImage: "trash")
                    }
                    .tint(.red)
                }
                .contextMenu {
                    Button("ลบ", systemImage: "trash", role: .destructive) {
                        documentPendingDeletion = document
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "ค้นหาชื่อหรือข้อความในเอกสาร")
        .overlay {
            if filteredDocuments.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                captureRequest = .camera
            } label: {
                Label("สแกนเอกสาร", systemImage: "doc.viewfinder")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.bottom, 8)
        }
        .confirmationDialog(
            "ลบเอกสารนี้?",
            isPresented: $documentPendingDeletion.isPresent(),
            titleVisibility: .visible,
            presenting: documentPendingDeletion
        ) { document in
            Button("ลบเอกสาร", role: .destructive) {
                store.deleteDocument(document.id)
            }
        } message: { document in
            Text("\"\(document.title)\" จะถูกลบถาวรและกู้คืนไม่ได้")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("ยังไม่มีเอกสาร", systemImage: "doc.viewfinder")
        } description: {
            Text("สแกนเอกสารด้วยกล้อง แอปจะตัดขอบและปรับมุมให้อัตโนมัติ แล้วอ่านข้อความภาษาไทยและอังกฤษให้")
        } actions: {
            Button("สแกนเอกสาร") {
                captureRequest = .camera
            }
            .buttonStyle(.borderedProminent)
            Button("นำเข้าจากรูปภาพ") {
                captureRequest = .photos
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button("สแกนด้วยกล้อง", systemImage: "doc.viewfinder") {
                captureRequest = .camera
            }
            Button("นำเข้าจากรูปภาพ", systemImage: "photo.on.rectangle") {
                captureRequest = .photos
            }
        } label: {
            Label("เพิ่มเอกสาร", systemImage: "plus")
        }
    }

    @MainActor
    private func saveNewDocument(_ pages: [CapturedPage]) async {
        if let document = await store.createDocument(from: pages) {
            searchText = ""
            path = [document.id]
        }
    }
}
