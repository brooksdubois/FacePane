import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    let overlayPaneGeometry = OverlayPaneGeometryState()
    private var windowController: WindowController?
    lazy var cameraService = CameraService(settingsStore: settingsStore)
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        let controller = WindowController(
            settingsStore: settingsStore,
            overlayPaneGeometry: overlayPaneGeometry,
            cameraService: cameraService,
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
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

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: "S"
        )
        settingsItem.keyEquivalentModifierMask = [.command, .shift]
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit WindowPane",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        EnvironmentValues().openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
