import SwiftUI
import UIKit

extension Binding {
    /// A Bool binding that is true while the optional holds a value; setting it to false clears the value.
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    self.wrappedValue = nil
                }
            }
        )
    }
}

/// Dims the screen with a spinner while something is being saved or loaded.
struct ProgressOverlay: View {
    let message: LocalizedStringKey

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            ProgressView(message)
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// Things that can be handed to the system share sheet.
struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// The system share sheet (AirDrop, Mail, Save to Files, ...).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
