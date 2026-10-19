import UIKit
import Vision

enum TextRecognizerError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        "อ่านไฟล์รูปภาพไม่ได้"
    }
}

/// On-device OCR with Vision. Thai needs iOS 17 or later and the `.accurate` recognition level.
enum TextRecognizer {
    /// Tried in this order. Languages the device doesn't support are dropped at runtime.
    static let preferredLanguages = ["th-TH", "en-US"]

    static func recognizeLines(inImageAt url: URL) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .utility) { () throws -> [RecognizedLine] in
            guard let cgImage = UIImage(contentsOfFile: url.path)?.cgImage else {
                throw TextRecognizerError.unreadableImage
            }
            return try TextRecognizer.recognizeLines(in: cgImage)
        }.value
    }

    /// Expects an upright image (stored pages are normalized to `.up` when saved).
    static func recognizeLines(in image: CGImage) throws -> [RecognizedLine] {
        do {
            return try performRecognition(on: image, languages: preferredLanguages)
        } catch {
            // Vision rejects some language combinations on some OS versions; retry with automatic detection.
            return try performRecognition(on: image, languages: nil)
        }
    }

    /// With no usable `languages`, Vision detects the language itself. Its default list is English only,
    /// which would read Thai as Latin letters.
    private static func performRecognition(on image: CGImage, languages: [String]?) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        let usable = (languages ?? []).filter { supported.contains($0) }
        if usable.isEmpty {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = usable
        }

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        return (request.results ?? []).compactMap { observation -> RecognizedLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return RecognizedLine(text: text, box: observation.boundingBox)
        }
    }
}
