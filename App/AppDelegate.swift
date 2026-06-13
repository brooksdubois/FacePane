import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: WindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        let controller = WindowController()
        self.windowController = controller

        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
