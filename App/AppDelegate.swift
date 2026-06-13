import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: WindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        let controller = WindowController()
        self.windowController = controller

        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.orderFrontRegardless()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "person.crop.rectangle.fill",
                accessibilityDescription: "WindowPane"
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(
            title: "Show WindowPane",
            action: #selector(showWindowPane),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit WindowPane",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        item.menu = menu
    }

    @objc private func showWindowPane() {
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        windowController?.window?.orderFrontRegardless()
    }

    @objc private func openSettings() {
        // Placeholder for now.
        // Later: open SwiftUI Settings window / popover.
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
