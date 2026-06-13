import SwiftUI

struct OverlayRootView: View {
    let cornerRadius: CGFloat

    @StateObject private var cameraService = CameraService()

    var body: some View {
        ZStack {
            CameraContentView(cameraService: cameraService)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            WindowPaneStroke(cornerRadius: cornerRadius)
        }
        .background(Color.clear)
        .onAppear {
            cameraService.start()
        }
        .onDisappear {
            cameraService.stop()
        }
    }
}

private struct CameraContentView: View {
    @ObservedObject var cameraService: CameraService

    var body: some View {
        ZStack {
            Color.black.opacity(0.86)

            switch cameraService.state {
            case .checkingPermission:
                CameraPlaceholderView(
                    systemImage: "video.fill",
                    title: "Preparing Camera",
                    message: "Windowpane is checking camera access."
                )
            case .ready:
                CameraPreviewView(session: cameraService.session)
            case .permissionDenied:
                CameraPlaceholderView(
                    systemImage: "video.slash.fill",
                    title: "Camera Permission Needed",
                    message: "Allow camera access in System Settings to show your live camera pane."
                )
            case .cameraUnavailable:
                CameraPlaceholderView(
                    systemImage: "video.slash.fill",
                    title: "No Camera Found",
                    message: "Connect a camera to show your live camera pane."
                )
            case .configurationFailed(let message):
                CameraPlaceholderView(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Camera Unavailable",
                    message: message
                )
            }
        }
    }
}

private struct WindowPaneStroke: View {
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.35), lineWidth: 2)
                .blur(radius: 0.5)
                .offset(y: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct CameraPlaceholderView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .semibold))

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.white)
        .padding(32)
    }
}
