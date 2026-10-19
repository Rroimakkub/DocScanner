import SwiftUI

@main
struct DocScannerApp: App {
    @State private var store = ScanStore()

    var body: some Scene {
        WindowGroup {
            ScanListView()
                .environment(store)
        }
    }
}
