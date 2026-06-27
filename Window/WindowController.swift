import AppKit
import Combine
import SwiftUI

final class WindowController: NSWindowController {
    private enum Metrics {
        static let defaultFrame = NSRect(x: 200, y: 200, width: 420, height: 300)
        static let minimumWindowSize = NSSize(width: 260, height: 160)
    }

    private enum OverlayWindowState {
        static let level: NSWindow.Level = .statusBar
        static let baseCollectionBehavior: NSWindow.CollectionBehavior = [.stationary, .ignoresCycle]
    }

    private let settingsStore: SettingsStore
    private let cameraService: CameraService
    private let presentationState: OverlayPresentationState
    private let resizableContentView: ResizableOverlayContentView
    private let onOpenSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var savedNormalFrame: NSRect?
    private var savedNormalWindowLevel: NSWindow.Level?
    private var isOverlayFullscreen = false

    init(
        settingsStore: SettingsStore,
        cameraService: CameraService,
        onOpenSettings: @escaping () -> Void
    ) {
        self.settingsStore = settingsStore
        self.cameraService = cameraService
        self.onOpenSettings = onOpenSettings

        let presentationState = OverlayPresentationState()
        self.presentationState = presentationState

        let initialCornerRadius = CGFloat(settingsStore.roundedCornerRadius)
        let initialWindowShape = settingsStore.windowShape
        let hostingView = NSHostingView(rootView: OverlayRootView(
            settingsStore: settingsStore,
            cameraService: cameraService,
            presentationState: presentationState,
            onToggleFullscreen: {}
        ))
        let contentView = ResizableOverlayContentView(
            contentView: hostingView,
            cornerRadius: initialCornerRadius,
            windowShape: initialWindowShape
        )
        self.resizableContentView = contentView

        let window = OverlayWindow(
            contentRect: settingsStore.restoredWindowFrame(defaultFrame: Metrics.defaultFrame),
            styleMask: [
                .borderless,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        window.title = "Windowpane"
        window.contentView = contentView
        window.isReleasedWhenClosed = false

        window.level = OverlayWindowState.level
        window.collectionBehavior = Self.collectionBehavior(showOnAllSpaces: settingsStore.showOnAllSpaces)

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = settingsStore.windowShadow

        window.isMovableByWindowBackground = true
        window.minSize = Metrics.minimumWindowSize

        super.init(window: window)

        hostingView.rootView = OverlayRootView(
            settingsStore: settingsStore,
            cameraService: cameraService,
            presentationState: presentationState,
            onToggleFullscreen: { [weak self] in
                self?.toggleOverlayFullscreen()
            }
        )
        window.onToggleOverlayFullscreen = { [weak self] in
            self?.toggleOverlayFullscreen()
        }
        window.onExitOverlayFullscreen = { [weak self] in
            guard self?.settingsStore.escapeExitsFullscreen == true else {
                return false
            }

            return self?.exitOverlayFullscreen() ?? false
        }
        window.onOpenSettings = { [weak self] in
            self?.onOpenSettings()
        }
        window.fullscreenShortcut = settingsStore.fullscreenShortcut
        window.delegate = self

        observeSettings()
        applyWindowSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)

        restoreFloatingOverlayBehavior(
            level: isOverlayFullscreen ? .screenSaver : OverlayWindowState.level,
            isMovable: !isOverlayFullscreen
        )
        window?.orderFrontRegardless()
    }

    private func observeSettings() {
        settingsStore.$showOnAllSpaces
            .sink { [weak self] _ in
                self?.applyWindowSettings()
            }
            .store(in: &cancellables)

        settingsStore.$windowShadow
            .sink { [weak self] _ in
                self?.applyWindowSettings()
            }
            .store(in: &cancellables)

        settingsStore.$roundedCornerRadius
            .sink { [weak self] cornerRadius in
                self?.resizableContentView.cornerRadius = CGFloat(cornerRadius)
            }
            .store(in: &cancellables)

        settingsStore.$windowShape
            .sink { [weak self] windowShape in
                self?.resizableContentView.windowShape = windowShape
            }
            .store(in: &cancellables)

        settingsStore.$fullscreenShortcut
            .sink { [weak self] shortcut in
                (self?.window as? OverlayWindow)?.fullscreenShortcut = shortcut
            }
            .store(in: &cancellables)

        settingsStore.$rememberWindowPosition
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveWindowFrameIfNeeded()
            }
            .store(in: &cancellables)

        settingsStore.$rememberWindowSize
            .dropFirst()
            .sink { [weak self] _ in
                self?.saveWindowFrameIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func applyWindowSettings() {
        guard let window else {
            return
        }

        window.collectionBehavior = Self.collectionBehavior(showOnAllSpaces: settingsStore.showOnAllSpaces)

        if !isOverlayFullscreen {
            window.level = OverlayWindowState.level
            window.hasShadow = settingsStore.windowShadow
        }

        window.isMovableByWindowBackground = !isOverlayFullscreen
        window.minSize = Metrics.minimumWindowSize
    }

    private func toggleOverlayFullscreen() {
        if isOverlayFullscreen {
            exitOverlayFullscreen()
        } else {
            enterOverlayFullscreen()
        }
    }

    private func enterOverlayFullscreen() {
        guard let window, !isOverlayFullscreen else {
            return
        }

        savedNormalFrame = window.frame
        savedNormalWindowLevel = window.level
        isOverlayFullscreen = true

        presentationState.isFullscreen = true
        resizableContentView.isResizeChromeEnabled = false
        restoreFloatingOverlayBehavior(level: .screenSaver, isMovable: false)
        window.hasShadow = false
        window.setFrame(targetFullscreenFrame(for: window), display: true, animate: false)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @discardableResult
    private func exitOverlayFullscreen() -> Bool {
        guard let window, isOverlayFullscreen else {
            return false
        }

        let frameToRestore = savedNormalFrame
        let levelToRestore = savedNormalWindowLevel ?? OverlayWindowState.level
        savedNormalFrame = nil
        savedNormalWindowLevel = nil
        isOverlayFullscreen = false

        presentationState.isFullscreen = false
        resizableContentView.isResizeChromeEnabled = true
        restoreFloatingOverlayBehavior(level: levelToRestore)
        window.hasShadow = settingsStore.windowShadow

        if let frameToRestore {
            window.setFrame(frameToRestore, display: true, animate: false)
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        return true
    }

    private func restoreFloatingOverlayBehavior(
        level: NSWindow.Level = OverlayWindowState.level,
        isMovable: Bool = true
    ) {
        guard let window else {
            return
        }

        window.level = level
        window.collectionBehavior = Self.collectionBehavior(showOnAllSpaces: settingsStore.showOnAllSpaces)
        window.isMovableByWindowBackground = isMovable
        window.minSize = Metrics.minimumWindowSize
    }

    private func targetFullscreenFrame(for window: NSWindow) -> NSRect {
        if let screen = window.screen {
            return screen.frame
        }

        let windowFrame = window.frame
        let screenContainingWindow = NSScreen.screens.max { first, second in
            first.frame.intersection(windowFrame).area < second.frame.intersection(windowFrame).area
        }

        return screenContainingWindow?.frame ?? NSScreen.main?.frame ?? windowFrame
    }

    private func saveWindowFrameIfNeeded() {
        guard let window, !isOverlayFullscreen else {
            return
        }

        settingsStore.saveWindowFrame(window.frame)
    }

    private static func collectionBehavior(showOnAllSpaces: Bool) -> NSWindow.CollectionBehavior {
        var behavior = OverlayWindowState.baseCollectionBehavior

        if showOnAllSpaces {
            behavior.insert(.canJoinAllSpaces)
        }

        return behavior
    }
}

extension WindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        saveWindowFrameIfNeeded()
    }

    func windowDidResize(_ notification: Notification) {
        saveWindowFrameIfNeeded()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveWindowFrameIfNeeded()
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull else {
            return 0
        }

        return width * height
    }
}

private final class ResizableOverlayContentView: NSView {
    private enum Metrics {
        static let resizeHitThickness: CGFloat = 24
    }

    private let contentView: NSView
    private let resizeHandle: ShapeAwareResizeHandleView
    var cornerRadius: CGFloat {
        didSet {
            resizeHandle.shapeGeometry = shapeGeometry
            invalidateResizeCursorRects()
            needsLayout = true
        }
    }
    var windowShape: WindowShape {
        didSet {
            resizeHandle.shapeGeometry = shapeGeometry
            invalidateResizeCursorRects()
            needsLayout = true
        }
    }
    var isResizeChromeEnabled: Bool = true {
        didSet {
            guard oldValue != isResizeChromeEnabled else {
                return
            }

            resizeHandle.isHidden = !isResizeChromeEnabled
            invalidateResizeCursorRects()
            needsLayout = true
        }
    }

    init(contentView: NSView, cornerRadius: CGFloat) {
        self.contentView = contentView
        self.cornerRadius = cornerRadius
        self.windowShape = .rounded
        self.resizeHandle = ShapeAwareResizeHandleView(
            shapeGeometry: WindowShapeGeometry(
                windowShape: .rounded,
                cornerRadius: cornerRadius
            ),
            hitThickness: Metrics.resizeHitThickness
        )

        super.init(frame: .zero)

        wantsLayer = false
        addSubview(contentView)
        // The interaction overlay intentionally covers the whole content view:
        // edge hits resize, while non-edge drags move the borderless window.
        // Keeping both paths here avoids SwiftUI/AppKit hit-test drift between
        // the visible frame, resize affordance, and fallback drag behavior.
        addSubview(resizeHandle)
    }

    convenience init(
        contentView: NSView,
        cornerRadius: CGFloat,
        windowShape: WindowShape
    ) {
        self.init(contentView: contentView, cornerRadius: cornerRadius)
        self.windowShape = windowShape
        resizeHandle.shapeGeometry = shapeGeometry

        resizeHandle.resizeCalculator = { [weak self] initialFrame, edges, deltaX, deltaY, minSize in
            self?.nextFrame(
                from: initialFrame,
                edges: edges,
                deltaX: deltaX,
                deltaY: deltaY,
                minSize: minSize
            ) ?? initialFrame
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        false
    }

    override func layout() {
        super.layout()

        contentView.frame = bounds
        resizeHandle.frame = isResizeChromeEnabled ? bounds : .zero
        invalidateResizeCursorRects()
    }

    private var shapeGeometry: WindowShapeGeometry {
        WindowShapeGeometry(
            windowShape: windowShape,
            cornerRadius: cornerRadius
        )
    }

    private func invalidateResizeCursorRects() {
        guard let window else {
            return
        }

        window.invalidateCursorRects(for: resizeHandle)
    }

    private func nextFrame(
        from initialWindowFrame: NSRect,
        edges: ResizeEdges,
        deltaX: CGFloat,
        deltaY: CGFloat,
        minSize: NSSize
    ) -> NSRect {
        switch shapeGeometry.windowShape {
        case .rounded:
            return roundedNextFrame(
                from: initialWindowFrame,
                edges: edges,
                deltaX: deltaX,
                deltaY: deltaY,
                minSize: minSize
            )
        case .circle:
            return circularNextFrame(
                from: initialWindowFrame,
                edges: edges,
                deltaX: deltaX,
                deltaY: deltaY,
                minSize: minSize
            )
        }
    }

    private func roundedNextFrame(
        from initialWindowFrame: NSRect,
        edges: ResizeEdges,
        deltaX: CGFloat,
        deltaY: CGFloat,
        minSize: NSSize
    ) -> NSRect {
        var newFrame = initialWindowFrame

        if edges.contains(.left) {
            newFrame.origin.x = initialWindowFrame.origin.x + deltaX
            newFrame.size.width = initialWindowFrame.size.width - deltaX

            if newFrame.size.width < minSize.width {
                newFrame.size.width = minSize.width
                newFrame.origin.x = initialWindowFrame.maxX - minSize.width
            }
        }

        if edges.contains(.right) {
            newFrame.size.width = max(minSize.width, initialWindowFrame.size.width + deltaX)
        }

        if edges.contains(.bottom) {
            newFrame.origin.y = initialWindowFrame.origin.y + deltaY
            newFrame.size.height = initialWindowFrame.size.height - deltaY

            if newFrame.size.height < minSize.height {
                newFrame.size.height = minSize.height
                newFrame.origin.y = initialWindowFrame.maxY - minSize.height
            }
        }

        if edges.contains(.top) {
            newFrame.size.height = max(minSize.height, initialWindowFrame.size.height + deltaY)
        }

        return newFrame
    }

    private func circularNextFrame(
        from initialWindowFrame: NSRect,
        edges: ResizeEdges,
        deltaX: CGFloat,
        deltaY: CGFloat,
        minSize: NSSize
    ) -> NSRect {
        let minSquareSize = max(minSize.width, minSize.height)
        let candidateDeltas: [CGFloat] = [
            edges.contains(.left) ? -deltaX : 0,
            edges.contains(.right) ? deltaX : 0,
            edges.contains(.bottom) ? -deltaY : 0,
            edges.contains(.top) ? deltaY : 0
        ].filter { $0 != 0 }

        guard let delta = candidateDeltas.max(by: { abs($0) < abs($1) }) else {
            return initialWindowFrame
        }

        let currentSide = min(initialWindowFrame.width, initialWindowFrame.height)
        let requestedSide = max(minSquareSize, currentSide + delta)

        if requestedSide == currentSide {
            return initialWindowFrame
        }

        let currentCircleFrame = NSRect(
            x: initialWindowFrame.minX + max(0, (initialWindowFrame.width - currentSide) / 2),
            y: initialWindowFrame.minY + max(0, (initialWindowFrame.height - currentSide) / 2),
            width: currentSide,
            height: currentSide
        )

        let nextOrigin: NSPoint
        if edges == .top {
            nextOrigin = NSPoint(
                x: currentCircleFrame.midX - (requestedSide / 2),
                y: currentCircleFrame.minY
            )
        } else if edges == .bottom {
            nextOrigin = NSPoint(
                x: currentCircleFrame.midX - (requestedSide / 2),
                y: currentCircleFrame.maxY - requestedSide
            )
        } else if edges == .left {
            nextOrigin = NSPoint(
                x: currentCircleFrame.maxX - requestedSide,
                y: currentCircleFrame.midY - (requestedSide / 2)
            )
        } else if edges == .right {
            nextOrigin = NSPoint(
                x: currentCircleFrame.minX,
                y: currentCircleFrame.midY - (requestedSide / 2)
            )
        } else {
            nextOrigin = NSPoint(
                x: edges.contains(.left) ? currentCircleFrame.maxX - requestedSide : currentCircleFrame.minX,
                y: edges.contains(.bottom) ? currentCircleFrame.maxY - requestedSide : currentCircleFrame.minY
            )
        }

        return NSRect(
            x: nextOrigin.x,
            y: nextOrigin.y,
            width: requestedSide,
            height: requestedSide
        )
    }
}

private struct ResizeEdges: OptionSet, Equatable {
    let rawValue: Int

    static let top = ResizeEdges(rawValue: 1 << 0)
    static let bottom = ResizeEdges(rawValue: 1 << 1)
    static let left = ResizeEdges(rawValue: 1 << 2)
    static let right = ResizeEdges(rawValue: 1 << 3)
}

/// Invisible resize/move chrome that consumes the same `WindowShapeGeometry`
/// contract used by `OverlayRootView` for clipping and strokes. The overlay
/// intentionally covers the full pane: edge hits resize, non-edge drags move
/// the borderless window, and non-edge double-clicks keep the fullscreen toggle.
private final class ShapeAwareResizeHandleView: NSView {
    private enum Metrics {
        static let flatCornerRadiusThreshold: CGFloat = 1
    }

    var shapeGeometry: WindowShapeGeometry
    let hitThickness: CGFloat
    var resizeCalculator: (NSRect, ResizeEdges, CGFloat, CGFloat, NSSize) -> NSRect = { initialFrame, _edges, _deltaX, _deltaY, minSize in
        return NSRect(
            origin: initialFrame.origin,
            size: NSSize(
                width: max(minSize.width, initialFrame.size.width),
                height: max(minSize.height, initialFrame.size.height)
            )
        )
    }
    private var activeEdges: ResizeEdges = []
    private var isDraggingWindow = false
    private var initialWindowFrame: NSRect = .zero
    private var initialMouseLocation: NSPoint = .zero
    private var resizeTrackingArea: NSTrackingArea?

    init(shapeGeometry: WindowShapeGeometry, hitThickness: CGFloat) {
        self.shapeGeometry = shapeGeometry
        self.hitThickness = hitThickness

        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, bounds.contains(point) else {
            return nil
        }

        return self
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let resizeTrackingArea {
            removeTrackingArea(resizeTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .cursorUpdate, .mouseMoved, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        resizeTrackingArea = trackingArea
    }

    override func cursorUpdate(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        activeEdges = resizeEdges(at: point) ?? []
        isDraggingWindow = activeEdges.isEmpty && window.isMovableByWindowBackground
        initialWindowFrame = window.frame
        initialMouseLocation = NSEvent.mouseLocation

        if event.clickCount == 2, activeEdges.isEmpty {
            isDraggingWindow = false
            (window as? OverlayWindow)?.onToggleOverlayFullscreen?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else {
            return
        }

        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - initialMouseLocation.x
        let deltaY = currentMouseLocation.y - initialMouseLocation.y

        if isDraggingWindow {
            var nextFrame = initialWindowFrame
            nextFrame.origin.x += deltaX
            nextFrame.origin.y += deltaY
            window.setFrame(nextFrame, display: true)
            return
        }

        guard !activeEdges.isEmpty else {
            return
        }

        let minSize = window.minSize
        let nextFrame = resizeCalculator(initialWindowFrame, activeEdges, deltaX, deltaY, minSize)

        window.setFrame(nextFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        activeEdges = []
        isDraggingWindow = false
    }

    private func updateCursor(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let edges = resizeEdges(at: point) {
            Self.cursor(for: edges).set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func resizeEdges(at point: NSPoint) -> ResizeEdges? {
        guard bounds.contains(point) else {
            return nil
        }

        switch shapeGeometry.windowShape {
        case .circle:
            return circularResizeEdges(at: point)
        case .rounded:
            return roundedResizeEdges(at: point)
        }
    }

    private func circularResizeEdges(at point: NSPoint) -> ResizeEdges? {
        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0 else {
            return nil
        }

        let circleRect = shapeGeometry.circleRect(in: bounds)
        let center = NSPoint(x: circleRect.midX, y: circleRect.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = diameter / 2
        let distanceFromCenter = hypot(dx, dy)

        guard abs(distanceFromCenter - radius) <= hitThickness else {
            return nil
        }

        return Self.edges(forVectorX: dx, y: dy)
    }

    private func roundedResizeEdges(at point: NSPoint) -> ResizeEdges? {
        let radius = shapeGeometry.roundedCornerRadius(in: bounds)

        if radius <= Metrics.flatCornerRadiusThreshold {
            return flatResizeEdges(at: point)
        }

        let straightEdges = straightRoundedResizeEdges(at: point, radius: radius)
        let cornerEdges = cornerRoundedResizeEdges(at: point, radius: radius)
        let edges = straightEdges.union(cornerEdges)

        return edges.isEmpty ? nil : edges
    }

    private func flatResizeEdges(at point: NSPoint) -> ResizeEdges? {
        var edges: ResizeEdges = []

        if point.x <= bounds.minX + hitThickness {
            edges.insert(.left)
        }
        if point.x >= bounds.maxX - hitThickness {
            edges.insert(.right)
        }
        if point.y <= bounds.minY + hitThickness {
            edges.insert(.bottom)
        }
        if point.y >= bounds.maxY - hitThickness {
            edges.insert(.top)
        }

        return edges.isEmpty ? nil : edges
    }

    private func straightRoundedResizeEdges(at point: NSPoint, radius: CGFloat) -> ResizeEdges {
        var edges: ResizeEdges = []
        let horizontalRange = (bounds.minX + radius)...(bounds.maxX - radius)
        let verticalRange = (bounds.minY + radius)...(bounds.maxY - radius)

        if horizontalRange.contains(point.x) {
            if point.y >= bounds.maxY - hitThickness {
                edges.insert(.top)
            }
            if point.y <= bounds.minY + hitThickness {
                edges.insert(.bottom)
            }
        }

        if verticalRange.contains(point.y) {
            if point.x <= bounds.minX + hitThickness {
                edges.insert(.left)
            }
            if point.x >= bounds.maxX - hitThickness {
                edges.insert(.right)
            }
        }

        return edges
    }

    private func cornerRoundedResizeEdges(at point: NSPoint, radius: CGFloat) -> ResizeEdges {
        let corners: [(center: NSPoint, edges: ResizeEdges, containsPoint: (CGFloat, CGFloat) -> Bool)] = [
            (NSPoint(x: bounds.minX + radius, y: bounds.maxY - radius), [.top, .left], { dx, dy in dx <= 0 && dy >= 0 }),
            (NSPoint(x: bounds.maxX - radius, y: bounds.maxY - radius), [.top, .right], { dx, dy in dx >= 0 && dy >= 0 }),
            (NSPoint(x: bounds.minX + radius, y: bounds.minY + radius), [.bottom, .left], { dx, dy in dx <= 0 && dy <= 0 }),
            (NSPoint(x: bounds.maxX - radius, y: bounds.minY + radius), [.bottom, .right], { dx, dy in dx >= 0 && dy <= 0 })
        ]

        for corner in corners {
            let dx = point.x - corner.center.x
            let dy = point.y - corner.center.y
            let distance = hypot(dx, dy)

            if corner.containsPoint(dx, dy), abs(distance - radius) <= hitThickness {
                return corner.edges
            }
        }

        return []
    }

    private static func edges(forVectorX x: CGFloat, y: CGFloat) -> ResizeEdges {
        let angle = atan2(y, x)
        let eighthTurn = CGFloat.pi / 8

        switch angle {
        case -eighthTurn...eighthTurn:
            return [.right]
        case eighthTurn...(3 * eighthTurn):
            return [.top, .right]
        case (3 * eighthTurn)...(5 * eighthTurn):
            return [.top]
        case (5 * eighthTurn)...(7 * eighthTurn):
            return [.top, .left]
        case (-3 * eighthTurn)...(-eighthTurn):
            return [.bottom, .right]
        case (-5 * eighthTurn)...(-3 * eighthTurn):
            return [.bottom]
        case (-7 * eighthTurn)...(-5 * eighthTurn):
            return [.bottom, .left]
        default:
            return [.left]
        }
    }

    private static func cursor(for edges: ResizeEdges) -> NSCursor {
        switch (edges.contains(.left) || edges.contains(.right), edges.contains(.top) || edges.contains(.bottom)) {
        case (true, true):
            return NSCursor.frameResize(position: cursorPosition(for: edges), directions: .all)
        case (true, false):
            return .resizeLeftRight
        case (false, true):
            return .resizeUpDown
        case (false, false):
            return .arrow
        }
    }

    private static func cursorPosition(for edges: ResizeEdges) -> NSCursor.FrameResizePosition {
        switch (edges.contains(.top), edges.contains(.bottom), edges.contains(.left), edges.contains(.right)) {
        case (true, false, true, false):
            return .topLeft
        case (true, false, false, true):
            return .topRight
        case (false, true, true, false):
            return .bottomLeft
        case (false, true, false, true):
            return .bottomRight
        case (true, false, false, false):
            return .top
        case (false, true, false, false):
            return .bottom
        case (false, false, true, false):
            return .left
        case (false, false, false, true):
            return .right
        default:
            return .topLeft
        }
    }
}
