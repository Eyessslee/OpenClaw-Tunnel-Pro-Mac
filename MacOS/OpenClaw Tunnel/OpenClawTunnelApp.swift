import SwiftUI

@main
struct OpenClawTunnelApp: App {
    var body: some Scene {
        WindowGroup(id: "mainWindow") {
            ContentView()
                .frame(width: 380, height: 640)
                .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
