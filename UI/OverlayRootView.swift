import AppKit
import Combine
import SwiftUI

final class OverlayPresentationState: ObservableObject {
    @Published var isFullscreen = false
}

struct OverlayRootView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var cameraService: CameraService
    @ObservedObject var presentationState: OverlayPresentationState

    let onToggleFullscreen: () -> Void

    var body: some View {
        ZStack {
            CameraContentView(
                cameraService: cameraService,
                isMirrored: settingsStore.mirrorCamera,
                cropPercent: settingsStore.cropPercent,
                cropCenterX: settingsStore.cropCenterX,
                cropCenterY: settingsStore.cropCenterY
            )
            .modifier(WindowShapeModifier(
                settingsStore: settingsStore,
                isFullscreen: presentationState.isFullscreen
            ))

            if !presentationState.isFullscreen {
                WindowPaneStroke(
                    settingsStore: settingsStore
                )
            }

            PaneInteractionOverlay(
                isMovableByDragging: !presentationState.isFullscreen,
                onDoubleClick: onToggleFullscreen
            )
        }
        .background(presentationState.isFullscreen ? Color.black : Color.clear)
        .ignoresSafeArea()
        .onAppear {
            cameraService.start()
        }
        .onDisappear {
            cameraService.stop()
        }
    }

}

private struct WindowShapeModifier: ViewModifier {
    @ObservedObject var settingsStore: SettingsStore
    let isFullscreen: Bool

    func body(content: Content) -> some View {
        guard !isFullscreen else {
            return AnyView(content)
        }

        let geometry = settingsStore.windowShapeGeometry

        switch geometry.windowShape {
        case .circle:
            return AnyView(content
                .clipShape(Circle()))
        case .rounded:
            return AnyView(content
                .clipShape(RoundedRectangle(cornerRadius: geometry.cornerRadius, style: .circular)))
        }
    }
}

private struct WindowPaneStroke: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        ZStack {
            let geometry = settingsStore.windowShapeGeometry

            switch geometry.windowShape {
            case .circle:
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)

                Circle()
                    .stroke(Color.black.opacity(0.35), lineWidth: 2)
                    .blur(radius: 0.5)
                    .offset(y: 1)
            case .rounded:
                RoundedRectangle(cornerRadius: geometry.cornerRadius, style: .circular)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)

                RoundedRectangle(cornerRadius: geometry.cornerRadius, style: .circular)
                    .stroke(Color.black.opacity(0.35), lineWidth: 2)
                    .blur(radius: 0.5)
                    .offset(y: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CameraContentView: View {
    @ObservedObject var cameraService: CameraService
    let isMirrored: Bool
    let cropPercent: Double
    let cropCenterX: Double
    let cropCenterY: Double

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
                GeometryReader { geometry in
                    let cropGeometry = CropGeometry(
                        cropPercent: cropPercent,
                        cropCenterX: cropCenterX,
                        cropCenterY: cropCenterY
                    )
                    let contentOffset = cropGeometry.contentOffset(in: geometry.size)

                    CameraPreviewView(
                        session: cameraService.session,
                        isMirrored: isMirrored
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(
                        CGSize(
                            width: cropGeometry.cropScale,
                            height: cropGeometry.cropScale
                        ),
                        anchor: .center
                    )
                    .offset(
                        x: contentOffset.width,
                        y: contentOffset.height
                    )
                }
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

private struct PaneInteractionOverlay: NSViewRepresentable {
    let isMovableByDragging: Bool
    let onDoubleClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDoubleClick: onDoubleClick)
    }

    func makeNSView(context: Context) -> PaneInteractionView {
        let view = PaneInteractionView()
        let recognizer = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleClick(_:))
        )
        recognizer.numberOfClicksRequired = 2
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateNSView(_ nsView: PaneInteractionView, context: Context) {
        nsView.isMovableByDragging = isMovableByDragging
        context.coordinator.onDoubleClick = onDoubleClick
    }

    final class Coordinator: NSObject {
        var onDoubleClick: () -> Void

        init(onDoubleClick: @escaping () -> Void) {
            self.onDoubleClick = onDoubleClick
        }

        @objc func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
            guard recognizer.state == .ended else {
                return
            }

            onDoubleClick()
        }
    }
}

private final class PaneInteractionView: NSView {
    var isMovableByDragging = true

    override var mouseDownCanMoveWindow: Bool {
        isMovableByDragging
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
