import AVFoundation
import Combine
import SwiftUI

@MainActor
final class CameraService: ObservableObject, @unchecked Sendable {
    enum State: Equatable {
        case checkingPermission
        case ready
        case permissionDenied
        case cameraUnavailable
        case configurationFailed(String)
    }

    @Published private(set) var state: State = .checkingPermission

    var session: AVCaptureSession {
        sessionRunner.session
    }

    private let permissionService: CameraPermissionService
    private let lifecycleToken = CameraLifecycleToken()
    private let sessionRunner = CameraSessionRunner()

    init(permissionService: CameraPermissionService = CameraPermissionService()) {
        self.permissionService = permissionService
    }

    deinit {
        lifecycleToken.advance()
        sessionRunner.stop()
    }

    func start() {
        assertMainThread()

        let generation = lifecycleToken.advance()

        switch permissionService.currentState {
        case .authorized:
            state = .checkingPermission
            startSession(generation: generation)
        case .notDetermined:
            state = .checkingPermission
            permissionService.requestAccess { [self] permissionState in
                Task { @MainActor in
                    handle(permissionState, generation: generation)
                }
            }
        case .denied, .restricted:
            state = .permissionDenied
        }
    }

    func stop() {
        assertMainThread()
        invalidateAndStopSession()
    }

    private func invalidateAndStopSession() {
        lifecycleToken.advance()
        sessionRunner.stop()
    }

    private func handle(_ permissionState: CameraPermissionService.PermissionState, generation: Int) {
        assertMainThread()

        guard lifecycleToken.isCurrent(generation) else {
            return
        }

        switch permissionState {
        case .authorized:
            startSession(generation: generation)
        case .notDetermined:
            state = .checkingPermission
        case .denied, .restricted:
            state = .permissionDenied
        }
    }

    private func startSession(generation: Int) {
        sessionRunner.start(generation: generation, lifecycleToken: lifecycleToken) { [self] generation, result in
            Task { @MainActor in
                guard lifecycleToken.isCurrent(generation) else {
                    return
                }

                switch result {
                case .ready:
                    state = .ready
                case .cameraUnavailable:
                    state = .cameraUnavailable
                case .configurationFailed(let message):
                    state = .configurationFailed(message)
                }
            }
        }
    }

    private func assertMainThread() {
        assert(Thread.isMainThread, "CameraService must be driven from the main thread.")
    }
}

nonisolated final class CameraLifecycleToken: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = 0

    @discardableResult
    func advance() -> Int {
        lock.lock()
        defer {
            lock.unlock()
        }

        generation += 1
        return generation
    }

    func isCurrent(_ generation: Int) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        return self.generation == generation
    }
}

nonisolated final class CameraSessionRunner: @unchecked Sendable {
    enum StartResult: Sendable {
        case ready
        case cameraUnavailable
        case configurationFailed(String)
    }

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.brooksdubois.WindowPane.camera-session")
    private var isConfigured = false

    func start(
        generation: Int,
        lifecycleToken: CameraLifecycleToken,
        completion: @escaping @Sendable (Int, StartResult) -> Void
    ) {
        sessionQueue.async { [self] in
            guard lifecycleToken.isCurrent(generation) else {
                return
            }

            do {
                try configureSessionIfNeeded()
            } catch {
                completion(generation, .configurationFailed(error.localizedDescription))
                return
            }

            guard isConfigured else {
                completion(generation, .cameraUnavailable)
                return
            }

            guard lifecycleToken.isCurrent(generation) else {
                return
            }

            if !session.isRunning {
                session.startRunning()
            }

            guard lifecycleToken.isCurrent(generation) else {
                return
            }

            completion(generation, .ready)
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            guard session.isRunning else {
                return
            }

            session.stopRunning()
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else {
            return
        }

        guard let camera = AVCaptureDevice.default(for: .video) else {
            return
        }

        let input = try AVCaptureDeviceInput(device: camera)

        session.beginConfiguration()
        session.sessionPreset = .high

        if session.canAddInput(input) {
            session.addInput(input)
            isConfigured = true
        }

        session.commitConfiguration()
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewLayerView {
        let view = CameraPreviewLayerView()
        view.configure(session: session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewLayerView, context: Context) {
        nsView.configure(session: session)
    }
}

final class CameraPreviewLayerView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer = previewLayer
        previewLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }

    func configure(session: AVCaptureSession) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }

        previewLayer.videoGravity = .resizeAspectFill
        mirrorPreviewIfPossible()
    }

    override func layout() {
        super.layout()

        previewLayer.frame = bounds
        mirrorPreviewIfPossible()
    }

    private func mirrorPreviewIfPossible() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else {
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }
}
