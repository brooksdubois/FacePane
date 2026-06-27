import SwiftUI

@main
struct FacePaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                settingsStore: appDelegate.settingsStore,
                overlayPaneGeometry: appDelegate.overlayPaneGeometry,
                cameraService: appDelegate.cameraService
            )
        }
    }
}
