import Foundation
import UIKit

enum ScanStoreError: LocalizedError {
    case imageEncodingFailed
    case documentNotFound

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "แปลงรูปภาพเป็นไฟล์ไม่สำเร็จ"
        case .documentNotFound:
            return "ไม่พบเอกสาร"
        }
    }
}

/// Disk layout: Documents/Scans/<document id>/document.json plus one JPEG per page.
/// Everything here is synchronous and actor-free so it can run on a background task.
enum ScanFiles {
    static let metadataFileName = "document.json"
    static let jpegQuality: CGFloat = 0.85
    /// Longest export file name before the extension, in UTF-8 bytes. File names are limited to 255 bytes,
    /// and a Thai character takes 3, so a long title would otherwise make the export fail.
    static let maxFileNameBytes = 200

    /// Loads every saved document. A document folder without document.json is left over from a save that never
    /// finished, so nothing can show it and it is removed. A document.json that exists but can't be read is kept
    /// on disk and only counted, so the user can be told instead of the document silently disappearing.
    static func loadDocuments(in root: URL) -> (documents: [ScanDocument], unreadableCount: Int) {
        let fileManager = FileManager.default
        let folders = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let decoder = JSONDecoder()
        var documents: [ScanDocument] = []
        var unreadableCount = 0
        for folder in folders where UUID(uuidString: folder.lastPathComponent) != nil {
            let metadataURL = folder.appending(path: metadataFileName, directoryHint: .notDirectory)
            guard fileManager.fileExists(atPath: metadataURL.path) else {
                try? fileManager.removeItem(at: folder)
                continue
            }
            if let data = try? Data(contentsOf: metadataURL),
               let document = try? decoder.decode(ScanDocument.self, from: data) {
                documents.append(document)
            } else {
                unreadableCount += 1
            }
        }
        return (documents, unreadableCount)
    }

    static func save(_ document: ScanDocument, in folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(document)
        try data.write(to: folder.appending(path: metadataFileName, directoryHint: .notDirectory), options: .atomic)
    }

    /// Writes each page as an upright JPEG, decoding one page at a time, and returns the matching
    /// (not yet OCR'd) pages. If any page fails, the images already written by this call are removed.
    static func writePages(_ captured: [CapturedPage], to folder: URL) throws -> [ScanPage] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var pages: [ScanPage] = []
        do {
            for source in captured {
                let page = try autoreleasepool { () throws -> ScanPage in
                    let id = UUID()
                    let page = ScanPage(id: id, imageFileName: "\(id.uuidString).jpg")
                    guard let image = source.makeImage(),
                          let data = ImageProcessing.prepareForStorage(image).jpegData(compressionQuality: jpegQuality) else {
                        throw ScanStoreError.imageEncodingFailed
                    }
                    try data.write(to: folder.appending(path: page.imageFileName, directoryHint: .notDirectory), options: .atomic)
                    return page
                }
                pages.append(page)
            }
        } catch {
            for page in pages {
                try? FileManager.default.removeItem(at: folder.appending(path: page.imageFileName, directoryHint: .notDirectory))
            }
            throw error
        }
        return pages
    }

    /// A file name safe for sharing, e.g. "สแกน 19 ต.ค. 2569.pdf".
    static func exportFileName(for title: String, pathExtension: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        var cleaned = title
            .components(separatedBy: invalid)
            .joined(separator: "-")
        // removeLast drops a whole character (grapheme), so a Thai vowel or tone mark is never cut off its base.
        while cleaned.utf8.count > maxFileNameBytes {
            cleaned.removeLast()
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(cleaned.isEmpty ? "Scan" : cleaned).\(pathExtension)"
    }
}
