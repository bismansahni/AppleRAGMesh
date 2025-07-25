

import SwiftUI

@main
struct MESH_PROJECTApp: App {
    
    
    init() {

        Task {
            await ModelLoader.preload()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MacMainView()
                .frame(minWidth: 400, maxWidth: .infinity,
                       minHeight: 100, maxHeight: .infinity)

                .background(Color.clear)
                .onAppear {
                    makeFloatingOverlay()
                }
        }
    }

    private func makeFloatingOverlay() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else { return }

            // Remove default chrome
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.styleMask.remove(.titled)
            window.styleMask.remove(.resizable)
            window.styleMask.insert(.fullSizeContentView)

            // Appearance and positioning
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isMovableByWindowBackground = true
            window.isMovable = false 

         
            if let screen = NSScreen.main {
                let width: CGFloat = 640
                let height: CGFloat = 320
                let x = (screen.frame.width - width) / 2
                let y = screen.frame.height - height - 100
                window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
            }

            window.setFrameAutosaveName("FloatingOverlay")
        }
    }
}

