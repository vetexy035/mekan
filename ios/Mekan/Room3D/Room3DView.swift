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
                        Button { exportURL = export() } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
                .sheet(item: $exportURL) { url in ShareSheet(items: [url]) }
        }
    }

    /// Writes the furnished room as USDZ. Uses a freshly built scene, never the one
    /// the SCNView is rendering, so the writer and the renderer don't share nodes.
    private func export() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mekan-mobilyali.usdz")
        try? FileManager.default.removeItem(at: url)
        let copy = RoomSceneBuilder.scene(for: scan)
        return copy.write(to: url, options: nil, delegate: nil, progressHandler: nil) ? url : nil
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
