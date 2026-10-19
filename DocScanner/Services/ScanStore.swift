import Foundation
import Observation
import UIKit

/// The app's single source of truth for saved scans. Files live under Documents/Scans (see `ScanFiles`).
@MainActor
@Observable
final class ScanStore {
    private(set) var documents: [ScanDocument] = []
    private(set) var recognizingDocumentIDs: Set<UUID> = []
    private(set) var savingCount = 0
    var errorMessage: String?

    var isSaving: Bool { savingCount > 0 }

    private struct RecognitionJob {
        let documentID: UUID
        let pageID: UUID
    }

    @ObservationIgnored private var recognitionQueue: [RecognitionJob] = []
    @ObservationIgnored private var isDrainingRecognitionQueue = false
    private let rootURL: URL

    init(rootURL: URL = URL.documentsDirectory.appending(path: "Scans", directoryHint: .isDirectory)) {
        self.rootURL = rootURL
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let loaded = ScanFiles.loadDocuments(in: rootURL)
        documents = loaded.documents.sorted { $0.createdAt > $1.createdAt }
        if loaded.unreadableCount > 0 {
            errorMessage = "เปิดเอกสารไม่ได้ \(loaded.unreadableCount) รายการ เพราะไฟล์ข้อมูลของเอกสารเสียหาย"
        }

        // Pick up OCR that was interrupted, e.g. the app was closed right after scanning.
        for document in documents {
            let pending = document.pages.filter { !$0.isTextRecognized }.map(\.id)
            enqueueRecognition(documentID: document.id, pageIDs: pending)
        }
    }

    // MARK: - Lookup

    func document(id: UUID) -> ScanDocument? {
        documents.first { $0.id == id }
    }

    func isRecognizing(_ documentID: UUID) -> Bool {
        recognizingDocumentIDs.contains(documentID)
    }

    func folderURL(for documentID: UUID) -> URL {
        rootURL.appending(path: documentID.uuidString, directoryHint: .isDirectory)
    }

    func imageURL(for page: ScanPage, in documentID: UUID) -> URL {
        folderURL(for: documentID).appending(path: page.imageFileName, directoryHint: .notDirectory)
    }

    func coverImageURL(for document: ScanDocument) -> URL? {
        document.pages.first.map { imageURL(for: $0, in: document.id) }
    }

    // MARK: - Changes

    /// Saves captured pages as a new document and starts OCR on it in the background.
    @discardableResult
    func createDocument(from captured: [CapturedPage]) async -> ScanDocument? {
        guard !captured.isEmpty else { return nil }
        let id = UUID()
        let folder = folderURL(for: id)
        savingCount += 1
        defer { savingCount -= 1 }

        do {
            let pages = try await Task.detached(priority: .userInitiated) {
                try ScanFiles.writePages(captured, to: folder)
            }.value
            let now = Date()
            let document = ScanDocument(
                id: id,
                title: "สแกน \(now.formatted(date: .abbreviated, time: .shortened))",
                createdAt: now,
                updatedAt: now,
                pages: pages
            )
            try ScanFiles.save(document, in: folder)
            documents.insert(document, at: 0)
            enqueueRecognition(documentID: id, pageIDs: pages.map(\.id))
            return document
        } catch {
            try? FileManager.default.removeItem(at: folder)
            errorMessage = "บันทึกเอกสารไม่สำเร็จ: \(error.localizedDescription)"
            return nil
        }
    }

    func addPages(_ captured: [CapturedPage], to documentID: UUID) async {
        guard !captured.isEmpty, document(id: documentID) != nil else { return }
        let folder = folderURL(for: documentID)
        savingCount += 1
        defer { savingCount -= 1 }

        do {
            // On failure writePages removes the images it already wrote, so no stray files are left behind.
            let pages = try await Task.detached(priority: .userInitiated) {
                try ScanFiles.writePages(captured, to: folder)
            }.value
            update(documentID) { document in
                document.pages.append(contentsOf: pages)
            }
            enqueueRecognition(documentID: documentID, pageIDs: pages.map(\.id))
        } catch {
            errorMessage = "เพิ่มหน้าไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    func rename(_ documentID: UUID, to newTitle: String) {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        update(documentID) { document in
            document.title = title
        }
    }

    func deleteDocument(_ documentID: UUID) {
        documents.removeAll { $0.id == documentID }
        recognitionQueue.removeAll { $0.documentID == documentID }
        recognizingDocumentIDs.remove(documentID)
        do {
            try FileManager.default.removeItem(at: folderURL(for: documentID))
        } catch {
            errorMessage = "ลบไฟล์ไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    /// Removes one page. The last page can't be removed; delete the whole document instead.
    func deletePage(_ pageID: UUID, from documentID: UUID) {
        guard let document = self.document(id: documentID),
              document.pages.count > 1,
              let page = document.pages.first(where: { $0.id == pageID }) else { return }
        update(documentID) { document in
            document.pages.removeAll { $0.id == pageID }
        }
        try? FileManager.default.removeItem(at: imageURL(for: page, in: documentID))
    }

    /// Runs OCR again on the pages of a document where it failed.
    func retryFailedRecognition(in documentID: UUID) {
        guard !isRecognizing(documentID), let document = document(id: documentID) else { return }
        enqueueRecognition(documentID: documentID, pageIDs: document.pages.filter(\.recognitionFailed).map(\.id))
    }

    // MARK: - Export

    /// Writes the document to a temporary PDF file and returns its URL, ready for the share sheet.
    func exportPDF(for documentID: UUID) async throws -> URL {
        guard let document = self.document(id: documentID) else { throw ScanStoreError.documentNotFound }
        let pages = document.pages.map { page in
            PDFExporter.Page(imageURL: imageURL(for: page, in: documentID), lines: page.lines)
        }
        let title = document.title
        let destination = URL.temporaryDirectory
            .appending(path: "Export", directoryHint: .isDirectory)
            .appending(path: documentID.uuidString, directoryHint: .isDirectory)
            .appending(path: ScanFiles.exportFileName(for: title, pathExtension: "pdf"), directoryHint: .notDirectory)

        try await Task.detached(priority: .userInitiated) {
            try PDFExporter.writePDF(pages: pages, title: title, to: destination)
        }.value
        return destination
    }

    // MARK: - Private

    private func update(_ documentID: UUID, touch: Bool = true, _ change: (inout ScanDocument) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        var document = documents[index]
        change(&document)
        if touch {
            document.updatedAt = Date()
        }
        documents[index] = document
        do {
            try ScanFiles.save(document, in: folderURL(for: documentID))
        } catch {
            errorMessage = "บันทึกข้อมูลเอกสารไม่สำเร็จ: \(error.localizedDescription)"
        }
    }

    /// OCR runs one page at a time so a long scan doesn't compete with itself for the CPU.
    private func enqueueRecognition(documentID: UUID, pageIDs: [UUID]) {
        guard !pageIDs.isEmpty else { return }
        recognitionQueue.append(contentsOf: pageIDs.map { RecognitionJob(documentID: documentID, pageID: $0) })
        recognizingDocumentIDs.insert(documentID)
        guard !isDrainingRecognitionQueue else { return }
        isDrainingRecognitionQueue = true
        Task {
            await drainRecognitionQueue()
        }
    }

    private func drainRecognitionQueue() async {
        while !recognitionQueue.isEmpty {
            let job = recognitionQueue.removeFirst()
            if let page = document(id: job.documentID)?.pages.first(where: { $0.id == job.pageID }) {
                let url = imageURL(for: page, in: job.documentID)
                let lines = try? await TextRecognizer.recognizeLines(inImageAt: url)
                update(job.documentID, touch: false) { document in
                    guard let index = document.pages.firstIndex(where: { $0.id == job.pageID }) else { return }
                    // A failed page is still marked as done so it isn't retried in a loop, but it is flagged
                    // so the user sees why it has no text and can retry it (`retryFailedRecognition`).
                    document.pages[index].lines = lines ?? []
                    document.pages[index].isTextRecognized = true
                    document.pages[index].recognitionFailed = lines == nil
                }
            }
            if !recognitionQueue.contains(where: { $0.documentID == job.documentID }) {
                recognizingDocumentIDs.remove(job.documentID)
            }
        }
        isDrainingRecognitionQueue = false
    }
}
