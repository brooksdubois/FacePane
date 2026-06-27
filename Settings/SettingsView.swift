import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var overlayPaneGeometry: OverlayPaneGeometryState
    @ObservedObject var cameraService: CameraService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection("General", systemImage: "slider.horizontal.3") {
                Toggle("Show on all Spaces", isOn: $settingsStore.showOnAllSpaces)
                Toggle("Remember last window position", isOn: $settingsStore.rememberWindowPosition)
                Toggle("Remember last window size", isOn: $settingsStore.rememberWindowSize)
            }

            SettingsDivider()

            SettingsSection("Window", systemImage: "macwindow") {
                Picker("Window shape", selection: $settingsStore.windowShape) {
                    ForEach(WindowShape.allCases) { shape in
                        Text(shape.displayName).tag(shape)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rounded corner radius")
                        Spacer()
                        Text("\(Int(settingsStore.roundedCornerRadius)) px")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { settingsStore.roundedCornerRadius },
                            set: { settingsStore.roundedCornerRadius = $0.rounded() }
                        ),
                        in: 0...80,
                    )
                    .disabled(settingsStore.windowShape == .circle)
                }

                Toggle("Window shadow", isOn: $settingsStore.windowShadow)
            }

            SettingsDivider()

            SettingsSection("Crop", systemImage: "crop") {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Crop amount")
                            Spacer()
                            Text("\(Int(settingsStore.cropPercent))%")
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { settingsStore.cropPercent },
                                set: { settingsStore.cropPercent = max(25, min(100, $0.rounded())) }
                            ),
                            in: 25...100
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    CropPositionSelector(
                        shapeGeometry: settingsStore.windowShapeGeometry,
                        paneSize: overlayPaneGeometry.paneSize,
                        cropPercent: settingsStore.cropPercent,
                        xOffset: $settingsStore.cropCenterX,
                        yOffset: $settingsStore.cropCenterY
                    )
                    .frame(
                        width: CropPositionSelector.previewSize(
                            for: settingsStore.windowShapeGeometry,
                            paneSize: overlayPaneGeometry.paneSize
                        ).width
                    )
                    .disabled(settingsStore.cropPercent >= 100)
                    .opacity(settingsStore.cropPercent >= 100 ? 0.45 : 1)
                }
            }

            SettingsDivider()

            SettingsSection("Camera", systemImage: "person.crop.rectangle") {
                Toggle("Mirror camera", isOn: $settingsStore.mirrorCamera)

                Picker("Camera device", selection: $settingsStore.selectedCameraUniqueID) {
                    Text("System Default").tag("")

                    ForEach(cameraService.availableVideoDevices) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }

                    if shouldShowUnavailableSelectedCamera {
                        Text("Selected camera unavailable").tag(settingsStore.selectedCameraUniqueID)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    cameraService.refreshAvailableVideoDevices()
                } label: {
                    Label("Refresh Cameras", systemImage: "arrow.clockwise")
                }
            }

            SettingsDivider()

            SettingsSection("Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right") {
                Picker("Keyboard shortcut", selection: $settingsStore.fullscreenShortcut) {
                    ForEach(FullscreenKeyboardShortcut.allCases) { shortcut in
                        Text(shortcut.displayName).tag(shortcut)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Escape exits fullscreen", isOn: $settingsStore.escapeExitsFullscreen)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(SettingsWindowConfigurator())
        .onAppear {
            cameraService.refreshAvailableVideoDevices()
        }
    }

    private var shouldShowUnavailableSelectedCamera: Bool {
        guard !settingsStore.selectedCameraUniqueID.isEmpty else {
            return false
        }

        return !cameraService.availableVideoDevices.contains {
            $0.uniqueID == settingsStore.selectedCameraUniqueID
        }
    }
}

private struct SettingsSection<Content: View>: View {
    private let title: String
    private let systemImage: String
    private let content: Content

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
            .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}

private struct CropPositionSelector: View {
    static let preferredMaximumSide: CGFloat = 164
    static let minimumSide: CGFloat = 72

    static func previewSize(
        for shapeGeometry: WindowShapeGeometry,
        paneSize: CGSize
    ) -> CGSize {
        switch shapeGeometry.windowShape {
        case .circle:
            return CGSize(
                width: preferredMaximumSide,
                height: preferredMaximumSide
            )
        case .rounded:
            let aspectRatio = paneAspectRatio(for: paneSize)

            if aspectRatio >= 1 {
                return CGSize(
                    width: preferredMaximumSide,
                    height: min(preferredMaximumSide, max(minimumSide, preferredMaximumSide / aspectRatio))
                )
            }

            return CGSize(
                width: min(preferredMaximumSide, max(minimumSide, preferredMaximumSide * aspectRatio)),
                height: preferredMaximumSide
            )
        }
    }

    let shapeGeometry: WindowShapeGeometry
    let paneSize: CGSize
    let cropPercent: Double
    @Binding var xOffset: Double
    @Binding var yOffset: Double

    private let pinSize: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Crop position")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Center") {
                    xOffset = 0
                    yOffset = 0
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(isCentered || isCropLocked)
            }

            GeometryReader { geometry in
                let bounds = CGRect(origin: .zero, size: geometry.size)
                let currentCropGeometry = cropGeometry
                let rawCropRect = currentCropGeometry.cropRect(in: bounds)
                let outerRadius = outerPreviewCornerRadius(
                    in: bounds,
                    cropRect: rawCropRect
                )
                let cropRadius = previewCornerRadius(in: rawCropRect)
                let cropRect = constrainedCropRect(
                    rawCropRect,
                    in: bounds,
                    outerRadius: outerRadius,
                    cropRadius: cropRadius
                )
                let pin = CGPoint(x: cropRect.midX, y: cropRect.midY)
                let outerShape = CropPreviewShape(
                    windowShape: .rounded,
                    cornerRadius: outerRadius
                )
                let cropShape = CropPreviewShape(
                    windowShape: shapeGeometry.windowShape,
                    cornerRadius: cropRadius
                )

                ZStack(alignment: .topLeading) {
                    outerShape
                        .fill(Color(nsColor: .controlBackgroundColor))

                    selectorGrid
                        .clipShape(outerShape)

                    outerShape
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)

                    cropShape
                        .fill(Color.accentColor.opacity(0.13))
                        .overlay {
                            cropShape
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                        .frame(width: cropRect.width, height: cropRect.height)
                        .position(x: cropRect.midX, y: cropRect.midY)

                    Path { path in
                        path.move(to: CGPoint(x: bounds.midX, y: 0))
                        path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
                        path.move(to: CGPoint(x: 0, y: bounds.midY))
                        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
                    }
                    .stroke(Color.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .clipShape(outerShape)

                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: pinSize, height: pinSize)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 1)
                        .position(pin)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateOffsets(from: value.location, in: bounds)
                        }
                )
            }
            .frame(height: selectorHeight)

            HStack {
                Text("X: \(Int((displayXOffset * 100).rounded()))%")
                Spacer()
                Text("Y: \(Int((displayYOffset * 100).rounded()))%")
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    private var selectorHeight: CGFloat {
        Self.previewSize(
            for: shapeGeometry,
            paneSize: paneSize
        ).height
    }

    private static func paneAspectRatio(for paneSize: CGSize) -> CGFloat {
        let width = max(1, paneSize.width)
        let height = max(1, paneSize.height)
        let minimumAspectRatio = minimumSide / preferredMaximumSide
        let maximumAspectRatio = preferredMaximumSide / minimumSide

        return min(maximumAspectRatio, max(minimumAspectRatio, width / height))
    }

    private var selectorGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 16
            var path = Path()

            var x: CGFloat = spacing
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = spacing
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(path, with: .color(Color.secondary.opacity(0.12)), lineWidth: 1)
        }
    }

    private var cropGeometry: CropGeometry {
        CropGeometry(
            cropPercent: cropPercent,
            cropCenterX: xOffset,
            cropCenterY: yOffset
        )
    }

    private var isCentered: Bool {
        abs(xOffset) < 0.001 && abs(yOffset) < 0.001
    }

    private var isCropLocked: Bool {
        cropGeometry.isCropLocked
    }

    private var displayXOffset: Double {
        displayedOffsets.x
    }

    private var displayYOffset: Double {
        displayedOffsets.y
    }

    private var displayedOffsets: (x: Double, y: Double) {
        guard !isCropLocked else {
            return (0, 0)
        }

        let bounds = CGRect(
            origin: .zero,
            size: Self.previewSize(
                for: shapeGeometry,
                paneSize: paneSize
            )
        )

        return offsetsForConstrainedCrop(
            cropGeometry,
            in: bounds
        )
    }

    private func updateOffsets(from location: CGPoint, in bounds: CGRect) {
        let proposedOffsets = cropGeometry.offsets(for: location, in: bounds)
        let proposedGeometry = CropGeometry(
            cropPercent: cropPercent,
            cropCenterX: proposedOffsets.x,
            cropCenterY: proposedOffsets.y
        )
        let offsets = offsetsForConstrainedCrop(
            proposedGeometry,
            in: bounds
        )
        xOffset = offsets.x
        yOffset = offsets.y
    }

    private func offsetsForConstrainedCrop(
        _ cropGeometry: CropGeometry,
        in bounds: CGRect
    ) -> (x: Double, y: Double) {
        let rawCropRect = cropGeometry.cropRect(in: bounds)
        let outerRadius = outerPreviewCornerRadius(
            in: bounds,
            cropRect: rawCropRect
        )
        let cropRadius = previewCornerRadius(in: rawCropRect)
        let cropRect = constrainedCropRect(
            rawCropRect,
            in: bounds,
            outerRadius: outerRadius,
            cropRadius: cropRadius
        )

        return cropGeometry.offsets(
            for: CGPoint(x: cropRect.midX, y: cropRect.midY),
            in: bounds
        )
    }

    private func constrainedCropRect(
        _ cropRect: CGRect,
        in bounds: CGRect,
        outerRadius: CGFloat,
        cropRadius: CGFloat
    ) -> CGRect {
        guard
            shapeGeometry.windowShape == .rounded,
            outerRadius > 0,
            cropRadius > 0
        else {
            return cropRect
        }

        var rect = cropRect
        let permittedCornerCenterDistance = max(0, outerRadius - cropRadius)

        for _ in 0..<8 {
            rect = rect.clamped(to: bounds)

            if rect.minX < bounds.minX + outerRadius, rect.minY < bounds.minY + outerRadius {
                rect = rect.offsetBy(
                    deltaToKeepCorner(
                        innerCornerCenter: CGPoint(x: rect.minX + cropRadius, y: rect.minY + cropRadius),
                        insideOuterCornerCenter: CGPoint(x: bounds.minX + outerRadius, y: bounds.minY + outerRadius),
                        maximumDistance: permittedCornerCenterDistance
                    )
                )
            }

            if rect.maxX > bounds.maxX - outerRadius, rect.minY < bounds.minY + outerRadius {
                rect = rect.offsetBy(
                    deltaToKeepCorner(
                        innerCornerCenter: CGPoint(x: rect.maxX - cropRadius, y: rect.minY + cropRadius),
                        insideOuterCornerCenter: CGPoint(x: bounds.maxX - outerRadius, y: bounds.minY + outerRadius),
                        maximumDistance: permittedCornerCenterDistance
                    )
                )
            }

            if rect.minX < bounds.minX + outerRadius, rect.maxY > bounds.maxY - outerRadius {
                rect = rect.offsetBy(
                    deltaToKeepCorner(
                        innerCornerCenter: CGPoint(x: rect.minX + cropRadius, y: rect.maxY - cropRadius),
                        insideOuterCornerCenter: CGPoint(x: bounds.minX + outerRadius, y: bounds.maxY - outerRadius),
                        maximumDistance: permittedCornerCenterDistance
                    )
                )
            }

            if rect.maxX > bounds.maxX - outerRadius, rect.maxY > bounds.maxY - outerRadius {
                rect = rect.offsetBy(
                    deltaToKeepCorner(
                        innerCornerCenter: CGPoint(x: rect.maxX - cropRadius, y: rect.maxY - cropRadius),
                        insideOuterCornerCenter: CGPoint(x: bounds.maxX - outerRadius, y: bounds.maxY - outerRadius),
                        maximumDistance: permittedCornerCenterDistance
                    )
                )
            }
        }

        return rect.clamped(to: bounds)
    }

    private func deltaToKeepCorner(
        innerCornerCenter: CGPoint,
        insideOuterCornerCenter outerCornerCenter: CGPoint,
        maximumDistance: CGFloat
    ) -> CGSize {
        let deltaX = innerCornerCenter.x - outerCornerCenter.x
        let deltaY = innerCornerCenter.y - outerCornerCenter.y
        let distance = hypot(deltaX, deltaY)

        guard distance > maximumDistance, distance > 0 else {
            return .zero
        }

        let scale = maximumDistance / distance
        let constrainedCornerCenter = CGPoint(
            x: outerCornerCenter.x + (deltaX * scale),
            y: outerCornerCenter.y + (deltaY * scale)
        )

        return CGSize(
            width: constrainedCornerCenter.x - innerCornerCenter.x,
            height: constrainedCornerCenter.y - innerCornerCenter.y
        )
    }

    private func previewCornerRadius(in bounds: CGRect) -> CGFloat {
        guard shapeGeometry.windowShape == .rounded else {
            return 0
        }

        let paneScale = min(
            bounds.width / max(1, paneSize.width),
            bounds.height / max(1, paneSize.height)
        )
        let scaledRadius = shapeGeometry.cornerRadius * paneScale
        let maxRadius = min(bounds.width, bounds.height) / 2

        guard shapeGeometry.cornerRadius > 0 else {
            return 0
        }

        return min(maxRadius, max(6, scaledRadius))
    }

    private func outerPreviewCornerRadius(
        in bounds: CGRect,
        cropRect: CGRect
    ) -> CGFloat {
        guard shapeGeometry.windowShape == .circle else {
            return previewCornerRadius(in: bounds)
        }

        return min(
            bounds.width / 2,
            bounds.height / 2,
            cropRect.width / 2,
            cropRect.height / 2
        )
    }
}

private extension CGRect {
    func clamped(to bounds: CGRect) -> CGRect {
        offsetBy(
            dx: min(max(bounds.minX - minX, 0), bounds.maxX - maxX),
            dy: min(max(bounds.minY - minY, 0), bounds.maxY - maxY)
        )
    }

    func offsetBy(_ delta: CGSize) -> CGRect {
        offsetBy(dx: delta.width, dy: delta.height)
    }
}

private struct CropPreviewShape: Shape {
    let windowShape: WindowShape
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        switch windowShape {
        case .circle:
            let side = min(rect.width, rect.height)
            let circleRect = CGRect(
                x: rect.midX - (side / 2),
                y: rect.midY - (side / 2),
                width: side,
                height: side
            )
            return Path(ellipseIn: circleRect)
        case .rounded:
            return Path(
                roundedRect: rect,
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 22)
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    private static let centeredTitleIdentifier = NSUserInterfaceItemIdentifier("FacePaneSettingsCenteredTitle")

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWhenAttached(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWhenAttached(nsView)
    }

    private func configureWhenAttached(_ view: NSView) {
        DispatchQueue.main.async {
            configure(window: view.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else {
            return
        }

        window.title = "FacePane Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.styleMask.remove(.fullSizeContentView)
        window.toolbar = nil
        window.toolbarStyle = .automatic

        configureCenteredTitle(in: window)
    }

    private func configureCenteredTitle(in window: NSWindow) {
        guard
            let closeButton = window.standardWindowButton(.closeButton),
            let titlebarView = closeButton.superview
        else {
            return
        }

        let existingTitleLabel = titlebarView.subviews.first {
            $0.identifier == Self.centeredTitleIdentifier
        } as? NSTextField

        let titleLabel = existingTitleLabel ?? NSTextField(labelWithString: "FacePane Settings")
        titleLabel.identifier = Self.centeredTitleIdentifier
        titleLabel.stringValue = "FacePane Settings"
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        if existingTitleLabel == nil {
            titlebarView.addSubview(titleLabel)
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: titlebarView.centerXAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
                titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titlebarView.leadingAnchor, constant: 120),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: titlebarView.trailingAnchor, constant: -120)
            ])
        }
    }
}
