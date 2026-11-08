import Foundation
import RoomPlan
import ARKit
import UIKit
import MekanCore

/// Owns the RoomCaptureView and its session. SwiftUI drives it through
/// `start()` / `finish()` and observes `state`.
@MainActor
final class RoomScanner: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case scanning
        case processing
        case finished
        case failed(String)
    }

    struct Result {
        let room: CapturedRoom
        let photo: UIImage?
    }

    static var isSupported: Bool { RoomCaptureSession.isSupported }

    @Published private(set) var state: State = .idle
    @Published private(set) var instruction: String?
    private(set) var result: Result?
    /// Multi-room mode: every finished room, all in the same world coordinates.
    @Published private(set) var rooms: [Result] = []

    let captureView: RoomCaptureView
    /// Keeps the AR session running between rooms so they share one coordinate
    /// system (required for StructureBuilder to merge them).
    let multiRoom: Bool
    private var lastPhoto: UIImage?

    init(multiRoom: Bool = false) {
        self.multiRoom = multiRoom
        captureView = multiRoom ? RoomCaptureView(frame: .zero, arSession: ARSession()) : RoomCaptureView(frame: .zero)
        super.init()
        captureView.delegate = self
        captureView.captureSession.delegate = self
    }

    func start() {
        result = nil
        lastPhoto = nil
        var config = RoomCaptureSession.Configuration()
        config.isCoachingEnabled = true
        captureView.captureSession.run(configuration: config)
        state = .scanning
    }

    /// Stops capture. RoomPlan then post-processes and calls `didPresent`.
    /// In multi-room mode the AR session keeps tracking while the user walks on.
    func finish() {
        guard state == .scanning else { return }
        lastPhoto = Self.snapshot(captureView.captureSession.arSession.currentFrame)
        captureView.captureSession.stop(pauseARSession: !multiRoom)
        state = .processing
    }

    /// Multi-room: stop tracking for good once the last room is done.
    func endSession() {
        captureView.captureSession.arSession.pause()
    }

    func cancel() {
        captureView.captureSession.stop()
        state = .idle
    }

    /// Converts the current camera frame (portrait) to a UIImage for the AI step.
    private static func snapshot(_ frame: ARFrame?) -> UIImage? {
        guard let buffer = frame?.capturedImage else { return nil }
        let ci = CIImage(cvPixelBuffer: buffer).oriented(.right)
        guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // RoomCaptureViewDelegate inherits NSCoding; RoomPlan never archives it.
    required init?(coder: NSCoder) { fatalError("not supported") }
}

extension RoomScanner: RoomCaptureViewDelegate {
    nonisolated func encode(with coder: NSCoder) {}

    nonisolated func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        true
    }

    nonisolated func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        Task { @MainActor in
            if let error {
                self.state = .failed(error.localizedDescription)
                return
            }
            let r = Result(room: processedResult, photo: self.lastPhoto)
            self.result = r
            if self.multiRoom { self.rooms.append(r) }
            self.state = .finished
        }
    }
}

extension RoomScanner: RoomCaptureSessionDelegate {
    nonisolated func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        let text: String? = switch instruction {
        case .moveCloseToWall: "Duvara biraz yaklaş"
        case .moveAwayFromWall: "Duvardan biraz uzaklaş"
        case .slowDown: "Daha yavaş hareket et"
        case .turnOnLight: "Ortam çok karanlık, ışığı aç"
        case .lowTexture: "Desenli bir yüzeye doğru tut"
        case .normal: nil
        @unknown default: nil
        }
        Task { @MainActor in self.instruction = text }
    }

    nonisolated func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error {
            Task { @MainActor in self.state = .failed(error.localizedDescription) }
        }
    }
}
