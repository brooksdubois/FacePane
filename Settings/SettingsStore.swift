import AppKit
import Combine

enum FullscreenKeyboardShortcut: String, CaseIterable, Identifiable {
    case optionShiftF
    case commandShiftF

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .optionShiftF:
            return "Option + Shift + F"
        case .commandShiftF:
            return "Command + Shift + F"
        }
    }

    func matches(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let character = event.charactersIgnoringModifiers?.lowercased()

        switch self {
        case .optionShiftF:
            return modifiers == [.option, .shift] && character == "f"
        case .commandShiftF:
            return modifiers == [.command, .shift] && character == "f"
        }
    }
}

enum WindowShape: String, CaseIterable, Identifiable {
    case rounded
    case circle

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .rounded:
            "Rounded Rectangle"
        case .circle:
            "Circle"
        }
    }
}

struct WindowShapeGeometry: Equatable {
    let windowShape: WindowShape
    let cornerRadius: CGFloat

    init(windowShape: WindowShape, cornerRadius: CGFloat) {
        self.windowShape = windowShape
        self.cornerRadius = max(0, cornerRadius)
    }

    func circleRect(in bounds: NSRect) -> NSRect {
        let diameter = min(bounds.width, bounds.height)

        return NSRect(
            x: bounds.minX + max(0, (bounds.width - diameter) / 2),
            y: bounds.minY + max(0, (bounds.height - diameter) / 2),
            width: diameter,
            height: diameter
        )
    }

    // Rounded panes use ordinary circular radius arcs. Keeping that contract
    // here lets the visible shape and AppKit resize hit geometry stay aligned.
    func roundedCornerRadius(in bounds: NSRect) -> CGFloat {
        min(cornerRadius, bounds.width / 2, bounds.height / 2)
    }
}

struct CropGeometry: Equatable {
    let cropPercent: Double
    let cropCenterX: Double
    let cropCenterY: Double

    var cropFraction: CGFloat {
        CGFloat(max(25, min(100, cropPercent)) / 100)
    }

    var cropScale: CGFloat {
        max(1, 1 / cropFraction)
    }

    var safeCropCenterX: Double {
        Self.clamp(cropCenterX)
    }

    var safeCropCenterY: Double {
        Self.clamp(cropCenterY)
    }

    var isCropLocked: Bool {
        cropPercent >= 100
    }

    func cropRect(in bounds: CGRect) -> CGRect {
        let cropSize = CGSize(
            width: bounds.width * cropFraction,
            height: bounds.height * cropFraction
        )
        let center = centerPoint(in: bounds)

        return CGRect(
            x: center.x - (cropSize.width / 2),
            y: center.y - (cropSize.height / 2),
            width: cropSize.width,
            height: cropSize.height
        )
    }

    func centerPoint(in bounds: CGRect) -> CGPoint {
        let cropWidth = bounds.width * cropFraction
        let cropHeight = bounds.height * cropFraction
        let travelX = max(0, (bounds.width - cropWidth) / 2)
        let travelY = max(0, (bounds.height - cropHeight) / 2)

        return CGPoint(
            x: bounds.midX + (CGFloat(safeCropCenterX) * travelX),
            y: bounds.midY - (CGFloat(safeCropCenterY) * travelY)
        )
    }

    func offsets(for location: CGPoint, in bounds: CGRect) -> (x: Double, y: Double) {
        guard !isCropLocked else {
            return (0, 0)
        }

        let cropWidth = bounds.width * cropFraction
        let cropHeight = bounds.height * cropFraction
        let travelX = max(0, (bounds.width - cropWidth) / 2)
        let travelY = max(0, (bounds.height - cropHeight) / 2)

        return (
            x: travelX == 0 ? 0 : Self.clamp(Double((location.x - bounds.midX) / travelX)),
            y: travelY == 0 ? 0 : Self.clamp(Double((bounds.midY - location.y) / travelY))
        )
    }

    func contentOffset(in size: CGSize) -> CGSize {
        CGSize(
            width: CGFloat(safeCropCenterX) * (size.width * (cropScale - 1) / 2),
            height: CGFloat(safeCropCenterY) * (size.height * (cropScale - 1) / 2)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        max(-1, min(1, value))
    }
}

@MainActor
final class OverlayPaneGeometryState: ObservableObject {
    @Published private(set) var paneSize = CGSize(width: 420, height: 300)

    func updatePaneSize(_ size: CGSize) {
        let normalizedSize = CGSize(
            width: max(1, size.width),
            height: max(1, size.height)
        )

        guard
            abs(paneSize.width - normalizedSize.width) > 0.5 ||
            abs(paneSize.height - normalizedSize.height) > 0.5
        else {
            return
        }

        paneSize = normalizedSize
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var showOnAllSpaces: Bool {
        didSet { defaults.set(showOnAllSpaces, forKey: Keys.showOnAllSpaces) }
    }

    @Published var rememberWindowPosition: Bool {
        didSet { defaults.set(rememberWindowPosition, forKey: Keys.rememberWindowPosition) }
    }

    @Published var rememberWindowSize: Bool {
        didSet { defaults.set(rememberWindowSize, forKey: Keys.rememberWindowSize) }
    }

    @Published var roundedCornerRadius: Double {
        didSet { defaults.set(roundedCornerRadius, forKey: Keys.roundedCornerRadius) }
    }

    @Published var windowShape: WindowShape {
        didSet { defaults.set(windowShape.rawValue, forKey: Keys.windowShape) }
    }

    @Published var cropPercent: Double {
        didSet { defaults.set(cropPercent, forKey: Keys.cropPercent) }
    }

    @Published var cropCenterX: Double {
        didSet { defaults.set(cropCenterX, forKey: Keys.cropCenterX) }
    }

    @Published var cropCenterY: Double {
        didSet { defaults.set(cropCenterY, forKey: Keys.cropCenterY) }
    }

    @Published var windowShadow: Bool {
        didSet { defaults.set(windowShadow, forKey: Keys.windowShadow) }
    }

    @Published var mirrorCamera: Bool {
        didSet { defaults.set(mirrorCamera, forKey: Keys.mirrorCamera) }
    }

    @Published var selectedCameraUniqueID: String {
        didSet { defaults.set(selectedCameraUniqueID, forKey: Keys.selectedCameraUniqueID) }
    }

    @Published var fullscreenShortcut: FullscreenKeyboardShortcut {
        didSet { defaults.set(fullscreenShortcut.rawValue, forKey: Keys.fullscreenShortcut) }
    }

    @Published var escapeExitsFullscreen: Bool {
        didSet { defaults.set(escapeExitsFullscreen, forKey: Keys.escapeExitsFullscreen) }
    }

    var windowShapeGeometry: WindowShapeGeometry {
        WindowShapeGeometry(
            windowShape: windowShape,
            cornerRadius: CGFloat(roundedCornerRadius)
        )
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        showOnAllSpaces = defaults.object(forKey: Keys.showOnAllSpaces) as? Bool ?? true
        rememberWindowPosition = defaults.object(forKey: Keys.rememberWindowPosition) as? Bool ?? false
        rememberWindowSize = defaults.object(forKey: Keys.rememberWindowSize) as? Bool ?? false
        roundedCornerRadius = defaults.object(forKey: Keys.roundedCornerRadius) as? Double ?? 28
        windowShadow = defaults.object(forKey: Keys.windowShadow) as? Bool ?? true
        windowShape = WindowShape(
            rawValue: defaults.string(forKey: Keys.windowShape) ?? WindowShape.rounded.rawValue
        ) ?? .rounded
        cropPercent = clamp(25, 100, defaults.object(forKey: Keys.cropPercent) as? Double ?? 100)
        cropCenterX = clamp(-1, 1, defaults.object(forKey: Keys.cropCenterX) as? Double ?? 0)
        cropCenterY = clamp(-1, 1, defaults.object(forKey: Keys.cropCenterY) as? Double ?? 0)
        mirrorCamera = defaults.object(forKey: Keys.mirrorCamera) as? Bool ?? true
        selectedCameraUniqueID = defaults.string(forKey: Keys.selectedCameraUniqueID) ?? ""

        let shortcutRawValue = defaults.string(forKey: Keys.fullscreenShortcut) ?? FullscreenKeyboardShortcut.optionShiftF.rawValue
        fullscreenShortcut = FullscreenKeyboardShortcut(rawValue: shortcutRawValue) ?? .optionShiftF

        escapeExitsFullscreen = defaults.object(forKey: Keys.escapeExitsFullscreen) as? Bool ?? true
    }

    func restoredWindowFrame(defaultFrame: NSRect) -> NSRect {
        var frame = defaultFrame

        if rememberWindowPosition, let origin = savedWindowOrigin {
            frame.origin = origin
        }

        if rememberWindowSize, let size = savedWindowSize {
            frame.size = size
        }

        return frame
    }

    func saveWindowFrame(_ frame: NSRect) {
        if rememberWindowPosition {
            defaults.set(Double(frame.origin.x), forKey: Keys.windowOriginX)
            defaults.set(Double(frame.origin.y), forKey: Keys.windowOriginY)
        }

        if rememberWindowSize {
            defaults.set(Double(frame.size.width), forKey: Keys.windowWidth)
            defaults.set(Double(frame.size.height), forKey: Keys.windowHeight)
        }
    }

    private var savedWindowOrigin: NSPoint? {
        guard
            defaults.object(forKey: Keys.windowOriginX) != nil,
            defaults.object(forKey: Keys.windowOriginY) != nil
        else {
            return nil
        }

        return NSPoint(
            x: defaults.double(forKey: Keys.windowOriginX),
            y: defaults.double(forKey: Keys.windowOriginY)
        )
    }

    private var savedWindowSize: NSSize? {
        guard
            defaults.object(forKey: Keys.windowWidth) != nil,
            defaults.object(forKey: Keys.windowHeight) != nil
        else {
            return nil
        }

        return NSSize(
            width: defaults.double(forKey: Keys.windowWidth),
            height: defaults.double(forKey: Keys.windowHeight)
        )
    }
}

private enum Keys {
    static let showOnAllSpaces = "settings.showOnAllSpaces"
    static let rememberWindowPosition = "settings.rememberWindowPosition"
    static let rememberWindowSize = "settings.rememberWindowSize"
    static let roundedCornerRadius = "settings.roundedCornerRadius"
    static let windowShape = "settings.windowShape"
    static let cropPercent = "settings.cropPercent"
    static let cropCenterX = "settings.cropCenterX"
    static let cropCenterY = "settings.cropCenterY"
    static let windowShadow = "settings.windowShadow"
    static let mirrorCamera = "settings.mirrorCamera"
    static let selectedCameraUniqueID = "settings.selectedCameraUniqueID"
    static let fullscreenShortcut = "settings.fullscreenShortcut"
    static let escapeExitsFullscreen = "settings.escapeExitsFullscreen"
    static let windowOriginX = "window.origin.x"
    static let windowOriginY = "window.origin.y"
    static let windowWidth = "window.size.width"
    static let windowHeight = "window.size.height"
}

private func clamp(_ minValue: Double, _ maxValue: Double, _ value: Double) -> Double {
    min(max(value, minValue), maxValue)
}
