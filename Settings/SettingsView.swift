import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var cameraService: CameraService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FacePane")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)

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
                        cropPercent: settingsStore.cropPercent,
                        xOffset: $settingsStore.cropCenterX,
                        yOffset: $settingsStore.cropCenterY
                    )
                    .frame(width: 164)
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
    let cropPercent: Double
    @Binding var xOffset: Double
    @Binding var yOffset: Double

    private let selectorHeight: CGFloat = 96
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
                let cropRect = cropRect(in: bounds)
                let pin = pinPoint(in: bounds)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))

                    selectorGrid
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)

                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.13))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
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

    private var cropFraction: CGFloat {
        CGFloat(max(25, min(100, cropPercent)) / 100)
    }

    private var isCentered: Bool {
        abs(xOffset) < 0.001 && abs(yOffset) < 0.001
    }

    private var isCropLocked: Bool {
        cropPercent >= 100
    }

    private var displayXOffset: Double {
        isCropLocked ? 0 : xOffset
    }

    private var displayYOffset: Double {
        isCropLocked ? 0 : yOffset
    }

    private func cropRect(in bounds: CGRect) -> CGRect {
        let cropSize = CGSize(
            width: bounds.width * cropFraction,
            height: bounds.height * cropFraction
        )
        let center = pinPoint(in: bounds)

        return CGRect(
            x: center.x - (cropSize.width / 2),
            y: center.y - (cropSize.height / 2),
            width: cropSize.width,
            height: cropSize.height
        )
    }

    private func pinPoint(in bounds: CGRect) -> CGPoint {
        let cropWidth = bounds.width * cropFraction
        let cropHeight = bounds.height * cropFraction
        let travelX = max(0, (bounds.width - cropWidth) / 2)
        let travelY = max(0, (bounds.height - cropHeight) / 2)

        return CGPoint(
            x: bounds.midX + (CGFloat(clamp(xOffset)) * travelX),
            y: bounds.midY - (CGFloat(clamp(yOffset)) * travelY)
        )
    }

    private func updateOffsets(from location: CGPoint, in bounds: CGRect) {
        guard !isCropLocked else {
            return
        }

        let cropWidth = bounds.width * cropFraction
        let cropHeight = bounds.height * cropFraction
        let travelX = max(0, (bounds.width - cropWidth) / 2)
        let travelY = max(0, (bounds.height - cropHeight) / 2)

        xOffset = travelX == 0 ? 0 : clamp(Double((location.x - bounds.midX) / travelX))
        yOffset = travelY == 0 ? 0 : clamp(Double((bounds.midY - location.y) / travelY))
    }

    private func clamp(_ value: Double) -> Double {
        max(-1, min(1, value))
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 22)
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
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

        window.title = "FacePane"
        window.titleVisibility = .visible
        window.toolbar = nil
        window.toolbarStyle = .automatic
    }
}
