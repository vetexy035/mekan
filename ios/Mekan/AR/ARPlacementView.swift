import SwiftUI
import RealityKit
import ARKit
import MekanCore

/// Live camera view: tap the floor to drop a true-to-size piece of furniture,
/// drag to move, twist with two fingers to rotate. Scaling is off on purpose.
struct ARPlacementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preset: FurniturePreset
    @State private var placed = false
    @State private var removeToken = 0

    init(preset: FurniturePreset = FurniturePreset.all[0]) {
        _preset = State(initialValue: preset)
    }

    var body: some View {
        ZStack {
            ARContainer(preset: preset, placed: $placed, removeToken: removeToken)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button("Kapat") { dismiss() }.buttonStyle(.bordered)
                    Spacer()
                    Menu {
                        ForEach(FurniturePreset.all) { p in
                            Button(p.name) { preset = p }
                        }
                    } label: {
                        Label("Mobilya", systemImage: "sofa")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                VStack(spacing: 4) {
                    Text(preset.name).font(.headline)
                    Text(sizeText).font(.subheadline.monospacedDigit())
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Spacer()

                Group {
                    if placed {
                        HStack {
                            Text("Kaydır: taşı · İki parmakla çevir: döndür").font(.footnote)
                            Button("Kaldır") { removeToken += 1; placed = false }.buttonStyle(.bordered)
                        }
                    } else {
                        Text("Telefonu zemine doğru tut, sonra yerleştirmek istediğin yere dokun.")
                            .font(.footnote).multilineTextAlignment(.center)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 30).padding(.horizontal)
            }
        }
    }

    private var sizeText: String {
        func cm(_ m: Double) -> Int { Int((m * 100).rounded()) }
        return "G \(cm(preset.size.width)) × D \(cm(preset.size.depth)) × Y \(cm(preset.size.height)) cm"
    }
}

private struct ARContainer: UIViewRepresentable {
    let preset: FurniturePreset
    @Binding var placed: Bool
    let removeToken: Int

    func makeCoordinator() -> Coordinator { Coordinator(placed: $placed) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            // Real furniture and walls hide the virtual piece behind them.
            view.environment.sceneUnderstanding.options.insert(.occlusion)
        }
        view.session.run(config)

        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: view.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:))))
        context.coordinator.view = view
        context.coordinator.preset = preset
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        let c = context.coordinator
        if c.preset != preset {
            c.preset = preset
            c.rebuildModel()
        }
        if c.removeToken != removeToken {
            c.removeToken = removeToken
            c.remove()
        }
    }

    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        view.session.pause()
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var view: ARView?
        var preset: FurniturePreset?
        var removeToken = 0
        private var anchor: AnchorEntity?
        private var model: ModelEntity?
        private var placed: Binding<Bool>

        init(placed: Binding<Bool>) { self.placed = placed }

        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let view, let preset else { return }
            let point = g.location(in: view)
            guard let hit = view.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal).first else { return }

            if let anchor {
                anchor.setTransformMatrix(hit.worldTransform, relativeTo: nil)
                return
            }
            let anchor = AnchorEntity(world: hit.worldTransform)
            let model = ARFurnitureBuilder.entity(for: preset)
            // Face the camera: front (-z) toward the viewer.
            let cam = view.cameraTransform.translation
            let pos = anchor.position(relativeTo: nil)
            let yaw = atan2(-(cam.x - pos.x), -(cam.z - pos.z))
            model.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            anchor.addChild(model)
            view.scene.addAnchor(anchor)
            view.installGestures([.translation, .rotation], for: model)
            self.anchor = anchor
            self.model = model
            placed.wrappedValue = true
        }

        func rebuildModel() {
            guard let view, let anchor, let preset, let old = model else { return }
            let new = ARFurnitureBuilder.entity(for: preset)
            new.transform = old.transform
            old.removeFromParent()
            anchor.addChild(new)
            view.installGestures([.translation, .rotation], for: new)
            model = new
        }

        func remove() {
            anchor?.removeFromParent()
            anchor = nil
            model = nil
        }
    }
}

/// Turns a FurnitureBlueprint into a RealityKit entity standing on its anchor.
enum ARFurnitureBuilder {
    static func entity(for preset: FurniturePreset) -> ModelEntity {
        let size = preset.blueprintSize
        let root = ModelEntity()
        let parts = FurnitureBlueprint.parts(category: preset.category, size: size, backSign: 1,
                                             attributes: preset.attributes)
        for part in parts {
            let mesh: MeshResource
            switch part.shape {
            case .box:
                let smallest = Float(min(part.size.x, part.size.y, part.size.z))
                mesh = .generateBox(width: Float(part.size.x), height: Float(part.size.y), depth: Float(part.size.z),
                                    cornerRadius: smallest * Float(min(part.rounding, 0.5)))
            case .cylinder:
                if #available(iOS 18.0, *) {
                    mesh = .generateCylinder(height: Float(part.size.y), radius: Float(part.size.x / 2))
                } else {
                    mesh = .generateBox(width: Float(part.size.x), height: Float(part.size.y), depth: Float(part.size.x))
                }
            }
            let child = ModelEntity(mesh: mesh, materials: [material(part.material)])
            // Blueprint is centered on the box; lift so the piece stands on the floor.
            child.position = [Float(part.center.x), Float(part.center.y + size.y / 2), Float(part.center.z)]
            root.addChild(child)
        }
        let box = ShapeResource.generateBox(width: Float(size.x), height: Float(size.y), depth: Float(size.z))
            .offsetBy(translation: [0, Float(size.y / 2), 0])
        root.collision = CollisionComponent(shapes: [box])
        return root
    }

    private static func material(_ m: FurniturePart.Material) -> SimpleMaterial {
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
        switch m {
        case .wood: return SimpleMaterial(color: c(0.72, 0.53, 0.34), roughness: 0.6, isMetallic: false)
        case .darkWood: return SimpleMaterial(color: c(0.33, 0.22, 0.15), roughness: 0.5, isMetallic: false)
        case .fabric: return SimpleMaterial(color: c(0.44, 0.49, 0.53), roughness: 0.95, isMetallic: false)
        case .cushion: return SimpleMaterial(color: c(0.58, 0.62, 0.65), roughness: 0.95, isMetallic: false)
        case .linen: return SimpleMaterial(color: c(0.94, 0.92, 0.87), roughness: 0.9, isMetallic: false)
        case .metal: return SimpleMaterial(color: c(0.78, 0.78, 0.78), roughness: 0.25, isMetallic: true)
        case .white: return SimpleMaterial(color: c(0.96, 0.96, 0.96), roughness: 0.45, isMetallic: false)
        case .dark: return SimpleMaterial(color: c(0.08, 0.08, 0.08), roughness: 0.2, isMetallic: false)
        case .glass: return SimpleMaterial(color: c(0.7, 0.85, 0.95, 0.5), roughness: 0.05, isMetallic: false)
        case .ceramic: return SimpleMaterial(color: c(0.98, 0.98, 0.98), roughness: 0.12, isMetallic: false)
        case .stone: return SimpleMaterial(color: c(0.55, 0.53, 0.50), roughness: 0.9, isMetallic: false)
        }
    }
}
