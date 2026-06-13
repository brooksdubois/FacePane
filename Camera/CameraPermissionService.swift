import AVFoundation

nonisolated struct CameraPermissionService: Sendable {
    enum PermissionState: Equatable, Sendable {
        case notDetermined
        case authorized
        case denied
        case restricted
    }

    var currentState: PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    func requestAccess(completion: @escaping @Sendable (PermissionState) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            completion(granted ? .authorized : .denied)
        }
    }
}
