import SwiftUI

@main
struct MekanApp: App {
    @StateObject private var store = ScanStore()

    var body: some Scene {
        WindowGroup {
            ScanListView().environmentObject(store)
        }
    }
}
