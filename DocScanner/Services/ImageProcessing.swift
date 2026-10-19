import ImageIO
import UIKit

enum ImageProcessing {
    /// Longest side kept on disk. Document camera pages are usually smaller than this already.
    static let maxStoredDimension: CGFloat = 3000

    /// Redraws the image upright (orientation `.up`) and scales very large photos down, so the stored
    /// JPEG, the OCR bounding boxes and the PDF page all share one coordinate space.
    static func prepareForStorage(_ image: UIImage) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longestSide = max(pixelSize.width, pixelSize.height)
        guard longestSide > 0 else { return image }
        let factor = min(1, maxStoredDimension / longestSide)
        if image.imageOrientation == .up && factor == 1 {
            return image
        }

        let targetSize = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Decodes a small version of an image file without loading the full image into memory.
    static func thumbnail(for url: URL, maxPixelSize: Int) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Loads page images off the main thread and keeps thumbnails in memory.
enum ImageLoader {
    private static let thumbnailCache = NSCache<NSString, UIImage>()

    static func thumbnail(for url: URL, maxPixelSize: Int) async -> UIImage? {
        let key = "\(url.path)|\(maxPixelSize)" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            ImageProcessing.thumbnail(for: url, maxPixelSize: maxPixelSize)
        }.value
        if let image {
            thumbnailCache.setObject(image, forKey: key)
        }
        return image
    }

    static func fullImage(at url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            return image.preparingForDisplay() ?? image
        }.value
    }
}
