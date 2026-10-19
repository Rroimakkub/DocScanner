import CoreText
import UIKit

enum PDFExporter {
    struct Page {
        var imageURL: URL
        var lines: [RecognizedLine]
    }

    /// Width of every PDF page in points (A4 is 595 x 842). The height follows each scan's aspect ratio.
    static let pageWidth: CGFloat = 595

    /// Writes one PDF page per scanned image. OCR text, when there is some, is drawn invisibly on top
    /// of the image at the same position, so the PDF can be searched and its text selected.
    static func writePDF(pages: [Page], title: String, to destination: URL) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "DocScanner",
        ]
        let defaultBounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * 1.414)
        let renderer = UIGraphicsPDFRenderer(bounds: defaultBounds, format: format)

        try renderer.writePDF(to: destination) { context in
            for page in pages {
                autoreleasepool {
                    guard let image = UIImage(contentsOfFile: page.imageURL.path),
                          image.size.width > 0, image.size.height > 0 else { return }
                    let bounds = CGRect(
                        x: 0,
                        y: 0,
                        width: pageWidth,
                        height: (pageWidth * image.size.height / image.size.width).rounded()
                    )
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    image.draw(in: bounds)
                    drawInvisibleText(page.lines, in: bounds, context: context.cgContext)
                }
            }
        }
    }

    private static func drawInvisibleText(_ lines: [RecognizedLine], in bounds: CGRect, context cg: CGContext) {
        guard !lines.isEmpty else { return }
        cg.saveGState()
        // PDF text render mode 3: present for search and selection, but never painted.
        cg.setTextDrawingMode(.invisible)

        for line in lines {
            let box = line.box
            // Vision uses a bottom-left origin; the PDF renderer's context draws from the top-left down.
            let rect = CGRect(
                x: bounds.minX + box.minX * bounds.width,
                y: bounds.minY + (1 - box.maxY) * bounds.height,
                width: box.width * bounds.width,
                height: box.height * bounds.height
            )
            guard rect.width > 1, rect.height > 1 else { continue }

            let font = UIFont.systemFont(ofSize: rect.height * 0.8)
            let attributed = NSAttributedString(string: line.text, attributes: [.font: font])
            let ctLine = CTLineCreateWithAttributedString(attributed)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            let measuredWidth = CGFloat(CTLineGetTypographicBounds(ctLine, &ascent, &descent, nil))
            guard measuredWidth > 0 else { continue }

            cg.saveGState()
            // Move to the baseline, stretch the line to the box width, and flip back to y-up for Core Text.
            cg.translateBy(x: rect.minX, y: rect.maxY - descent)
            cg.scaleBy(x: rect.width / measuredWidth, y: -1)
            cg.textMatrix = .identity
            cg.textPosition = .zero
            CTLineDraw(ctLine, cg)
            cg.restoreGState()
        }

        cg.restoreGState()
    }
}
