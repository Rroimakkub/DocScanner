import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

/// Where new pages come from.
enum CaptureSource {
    case camera
    case photos
}

enum CameraProblem: Identifiable, Hashable {
    case unsupported
    case denied
    /// The document camera stopped with an error; holds its description.
    case failed(String)

    var id: Self { self }

    var title: String {
        switch self {
        case .unsupported:
            return "ใช้กล้องสแกนไม่ได้"
        case .denied:
            return "ไม่ได้รับอนุญาตให้ใช้กล้อง"
        case .failed:
            return "สแกนไม่สำเร็จ"
        }
    }

    var message: String {
        switch self {
        case .unsupported:
            return "อุปกรณ์นี้ไม่รองรับการสแกนเอกสารด้วยกล้อง (เช่น Simulator) ลองนำเข้าจากรูปภาพแทน"
        case .denied:
            return "เปิดสิทธิ์กล้องให้แอปนี้ได้ที่ การตั้งค่า > สแกนเอกสาร > กล้อง"
        case let .failed(description):
            return "กล้องสแกนเอกสารเกิดข้อผิดพลาด ลองสแกนใหม่อีกครั้ง\n(\(description))"
        }
    }

    /// Returns nil when the document camera can be shown, asking for permission first if needed.
    @MainActor
    static func check() async -> CameraProblem? {
        guard VNDocumentCameraViewController.isSupported else { return .unsupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return nil
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? nil : .denied
        default:
            return .denied
        }
    }
}

/// Shows the document camera or the photo picker whenever `request` is set, then hands back the pages.
private struct PageCaptureModifier: ViewModifier {
    @Binding var request: CaptureSource?
    let onCapture: ([CapturedPage]) -> Void

    @State private var isShowingCamera = false
    /// A camera error waiting for the camera to finish closing, since an alert can't appear while it is on screen.
    @State private var pendingCameraProblem: CameraProblem?
    @State private var isShowingPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var cameraProblem: CameraProblem?
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, source in
                guard let source else { return }
                request = nil
                switch source {
                case .camera:
                    Task { await openCamera() }
                case .photos:
                    isShowingPhotoPicker = true
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera, onDismiss: {
                if let problem = pendingCameraProblem {
                    pendingCameraProblem = nil
                    cameraProblem = problem
                }
            }) {
                DocumentCameraView { pages in
                    isShowingCamera = false
                    if !pages.isEmpty {
                        onCapture(pages)
                    }
                } onCancel: {
                    isShowingCamera = false
                } onFailure: { error in
                    pendingCameraProblem = .failed(error.localizedDescription)
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $isShowingPhotoPicker,
                selection: $photoItems,
                maxSelectionCount: 30,
                selectionBehavior: .ordered,
                matching: .images
            )
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                photoItems = []
                Task { await importPhotos(items) }
            }
            .overlay {
                if isLoadingPhotos {
                    ProgressOverlay(message: "กำลังนำเข้ารูปภาพ…")
                }
            }
            .alert(
                cameraProblem?.title ?? "",
                isPresented: $cameraProblem.isPresent(),
                presenting: cameraProblem
            ) { problem in
                if problem == .denied {
                    Button("เปิดการตั้งค่า") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
                Button("ตกลง", role: .cancel) {}
            } message: { problem in
                Text(problem.message)
            }
    }

    @MainActor
    private func openCamera() async {
        if let problem = await CameraProblem.check() {
            cameraProblem = problem
        } else {
            isShowingCamera = true
        }
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        var pages: [CapturedPage] = []
        for item in items {
            // Keep the encoded file rather than a decoded image; pages are decoded one by one while saving.
            if let data = try? await item.loadTransferable(type: Data.self), ImageProcessing.canDecode(data) {
                pages.append(.imageData(data))
            }
        }
        isLoadingPhotos = false
        if !pages.isEmpty {
            onCapture(pages)
        }
    }
}

extension View {
    /// Set `request` to `.camera` or `.photos` to start capturing; `onCapture` receives the pages in order.
    func pageCapture(_ request: Binding<CaptureSource?>, onCapture: @escaping ([CapturedPage]) -> Void) -> some View {
        modifier(PageCaptureModifier(request: request, onCapture: onCapture))
    }
}
