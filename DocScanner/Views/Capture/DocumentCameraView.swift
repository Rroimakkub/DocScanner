import SwiftUI
import VisionKit

/// VisionKit's document camera: finds the page edges, corrects perspective and can capture several pages.
struct DocumentCameraView: UIViewControllerRepresentable {
    var onFinish: ([CapturedPage]) -> Void
    var onCancel: () -> Void
    var onFailure: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentCameraView

        init(parent: DocumentCameraView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // The page images are read from the scan one at a time while saving, not all at once here.
            parent.onFinish((0..<scan.pageCount).map { CapturedPage.scan(scan, index: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onFailure(error)
        }
    }
}
