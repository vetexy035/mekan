import SwiftUI
import SceneKit
import MekanCore

private struct SceneViewRepresentable: UIViewRepresentable {
    let scene: SCNScene
    let camera: SCNNode

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .systemGroupedBackground
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        guard view.pointOfView !== camera else { return }
        if camera.parent == nil { scene.rootNode.addChildNode(camera) }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        view.pointOfView = camera
        SCNTransaction.commit()
    }
}

/// Furnished 3D room: orbit with one finger, zoom with pinch, pan with two fingers.
struct Room3DView: View {
    @Environment(\.dismiss) private var dismiss
    let scan: RoomScan

    @State private var scene: SCNScene
    @State private var topDown = false
    @State private var perspectiveCamera: SCNNode
    @State private var topCamera: SCNNode
    @State private var exportURL: URL?

    init(scan: RoomScan) {
        self.scan = scan
        _scene = State(initialValue: RoomSceneBuilder.scene(for: scan))
        _perspectiveCamera = State(initialValue: RoomSceneBuilder.cameraNode(for: scan, topDown: false))
        _topCamera = State(initialValue: RoomSceneBuilder.cameraNode(for: scan, topDown: true))
    }

    var body: some View {
        NavigationStack {
            SceneViewRepresentable(scene: scene, camera: topDown ? topCamera : perspectiveCamera)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(scan.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
                    ToolbarItem(placement: .principal) {
                        Picker("Görünüm", selection: $topDown) {
                            Text("Perspektif").tag(false)
                            Text("Kuş bakışı").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if let exportURL {
                            ShareLink(item: exportURL) { Image(systemName: "square.and.arrow.up") }
                        }
                    }
                }
                .task { exportURL = export() }
        }
    }

    /// Writes the furnished scene as USDZ so it can be shared or opened in AR Quick Look.
    private func export() -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(scan.name)-mobilyali.usdz")
        try? FileManager.default.removeItem(at: url)
        return scene.write(to: url, options: nil, delegate: nil, progressHandler: nil) ? url : nil
    }
}
