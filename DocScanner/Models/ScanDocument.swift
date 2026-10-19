import CoreGraphics
import Foundation

/// One line of text found by OCR, with where it sits on the page.
struct RecognizedLine: Codable, Hashable {
    var text: String
    // Normalized (0...1) bounding box in Vision coordinates: the origin is the bottom-left corner.
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(text: String, box: CGRect) {
        self.text = text
        x = Double(box.minX)
        y = Double(box.minY)
        width = Double(box.width)
        height = Double(box.height)
    }

    var box: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct ScanPage: Codable, Hashable, Identifiable {
    var id: UUID
    /// JPEG file name inside the document's folder.
    var imageFileName: String
    var lines: [RecognizedLine] = []
    /// False until OCR has run on this page, so unfinished pages can be resumed on the next launch.
    var isTextRecognized = false

    var text: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

struct ScanDocument: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var pages: [ScanPage]

    var fullText: String {
        pages.map(\.text).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
