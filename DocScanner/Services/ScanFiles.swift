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

    static func loadDocuments(in root: URL) -> [ScanDocument] {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let decoder = JSONDecoder()
        return folders.compactMap { folder in
            let metadataURL = folder.appending(path: metadataFileName, directoryHint: .notDirectory)
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            return try? decoder.decode(ScanDocument.self, from: data)
        }
    }

    static func save(_ document: ScanDocument, in folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(document)
        try data.write(to: folder.appending(path: metadataFileName, directoryHint: .notDirectory), options: .atomic)
    }

    /// Writes each image as an upright JPEG and returns the matching (not yet OCR'd) pages.
    static func writePages(_ images: [UIImage], to folder: URL) throws -> [ScanPage] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try images.map { image in
            try autoreleasepool { () throws -> ScanPage in
                let id = UUID()
                let page = ScanPage(id: id, imageFileName: "\(id.uuidString).jpg")
                let prepared = ImageProcessing.prepareForStorage(image)
                guard let data = prepared.jpegData(compressionQuality: jpegQuality) else {
                    throw ScanStoreError.imageEncodingFailed
                }
                try data.write(to: folder.appending(path: page.imageFileName, directoryHint: .notDirectory), options: .atomic)
                return page
            }
        }
    }

    /// A file name safe for sharing, e.g. "สแกน 19 ต.ค. 2569.pdf".
    static func exportFileName(for title: String, pathExtension: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(cleaned.isEmpty ? "Scan" : cleaned).\(pathExtension)"
    }
}
