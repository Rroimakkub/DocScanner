import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

/// Where new pages come from.
enum CaptureSource {
    case camera
    case photos
}

enum CameraProblem: Identifiable {
    case unsupported
    case denied

    var id: Self { self }

    var title: String {
        switch self {
        case .unsupported:
            return "ใช้กล้องสแกนไม่ได้"
        case .denied:
            return "ไม่ได้รับอนุญาตให้ใช้กล้อง"
        }
    }

    var message: String {
        switch self {
        case .unsupported:
            return "อุปกรณ์นี้ไม่รองรับการสแกนเอกสารด้วยกล้อง (เช่น Simulator) ลองนำเข้าจากรูปภาพแทน"
        case .denied:
            return "เปิดสิทธิ์กล้องให้แอปนี้ได้ที่ การตั้งค่า > สแกนเอกสาร > กล้อง"
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

/// Shows the document camera or the photo picker whenever `request` is set, then hands back the images.
private struct PageCaptureModifier: ViewModifier {
    @Binding var request: CaptureSource?
    let onCapture: ([UIImage]) -> Void

    @State private var isShowingCamera = false
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
            .fullScreenCover(isPresented: $isShowingCamera) {
                DocumentCameraView { images in
                    isShowingCamera = false
                    if !images.isEmpty {
                        onCapture(images)
                    }
                } onCancel: {
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
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        isLoadingPhotos = false
        if !images.isEmpty {
            onCapture(images)
        }
    }
}

extension View {
    /// Set `request` to `.camera` or `.photos` to start capturing; `onCapture` receives the pages in order.
    func pageCapture(_ request: Binding<CaptureSource?>, onCapture: @escaping ([UIImage]) -> Void) -> some View {
        modifier(PageCaptureModifier(request: request, onCapture: onCapture))
    }
}
