import SwiftUI

@main
struct LunchpadApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .onAppear {
                    DispatchQueue.main.async {
                        if let window = NSApplication.shared.windows.first {
                            window.titleVisibility = .hidden
                            window.titlebarAppearsTransparent = true
                            window.styleMask.remove(.titled)
                            window.isOpaque = true
                            window.standardWindowButton(.closeButton)?.isHidden = true
                            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                            window.standardWindowButton(.zoomButton)?.isHidden = true
                            window.styleMask.insert(.fullSizeContentView)
                            window.styleMask.remove(.resizable)
                            if let screen = NSScreen.main {
                                window.setFrame(screen.visibleFrame, display: true)
                                window.center()
                            }
                        }
                    }
                }
        }
    }
}
