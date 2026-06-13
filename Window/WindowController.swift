import AppKit
import SwiftUI

final class WindowController: NSWindowController {
    convenience init() {
        let rootView = OverlayRootView()
        let hostingView = NSHostingView(rootView: rootView)

        let window = OverlayWindow(
            contentRect: NSRect(x: 200, y: 200, width: 420, height: 300),
            styleMask: [
                .borderless,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "Windowpane"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false

        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 260, height: 160)

        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)

        window?.level = .statusBar
        window?.orderFrontRegardless()
    }
}
