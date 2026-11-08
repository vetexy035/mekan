import SceneKit
import UIKit
import MekanCore

/// Builds a furnished SceneKit scene from a RoomScan: floor, walls, doors,
/// windows and procedurally modeled furniture at the detected sizes.
enum RoomSceneBuilder {
    static let wallThickness: CGFloat = 0.08

    static func scene(for scan: RoomScan) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        root.addChildNode(floor(for: scan))
        for wall in scan.walls { root.addChildNode(wallNode(wall)) }

        // RoomPlan heights start at the phone, not the floor; our floor is y = 0.
        let floorY = scan.estimatedFloorY

        let wallsById = Dictionary(scan.walls.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for opening in scan.openings {
            let wall = opening.wallId.flatMap { wallsById[$0] } ?? nearestWall(to: opening, in: scan.walls)
            if let node = openingNode(opening, wall: wall, floorY: floorY) {
                root.addChildNode(node)
            }
        }

        let tables = scan.objects.filter { $0.category == "table" }
        for object in scan.objects {
            root.addChildNode(furnitureNode(object, walls: scan.walls, tables: tables, floorY: floorY))
        }

        addLights(to: root)
        return scene
    }

    // MARK: Structure

    private static func floor(for scan: RoomScan) -> SCNNode {
        let points: [Point2]
        if let polygon = RoomMeasurements.floorPolygon(scan.walls) {
            points = polygon
        } else {
            let pts = scan.walls.flatMap { [$0.start, $0.end] }
            let xs = pts.map(\.x), zs = pts.map(\.z)
            guard let x0 = xs.min(), let x1 = xs.max(), let z0 = zs.min(), let z1 = zs.max() else { return SCNNode() }
            points = [Point2(x: x0, z: z0), Point2(x: x1, z: z0), Point2(x: x1, z: z1), Point2(x: x0, z: z1)]
        }
        // SCNShape lives in the XY plane; rotating -90° about X maps (x, y) to world (x, -y on z).
        let path = UIBezierPath()
        path.move(to: CGPoint(x: points[0].x, y: -points[0].z))
        for p in points.dropFirst() { path.addLine(to: CGPoint(x: p.x, y: -p.z)) }
        path.close()
        let shape = SCNShape(path: path, extrusionDepth: 0.02)
        shape.materials = [material(UIColor(red: 0.78, green: 0.66, blue: 0.52, alpha: 1), roughness: 0.7)]
        let node = SCNNode(geometry: shape)
        node.eulerAngles.x = -.pi / 2
        node.position.y = -0.01
        node.name = "floor"
        return node
    }

    private static func wallNode(_ wall: Wall) -> SCNNode {
        let box = SCNBox(width: CGFloat(wall.length), height: CGFloat(wall.height), length: wallThickness, chamferRadius: 0)
        box.materials = [material(UIColor(white: 0.95, alpha: 1), roughness: 0.9)]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3((wall.start.x + wall.end.x) / 2, wall.height / 2, (wall.start.z + wall.end.z) / 2)
        node.eulerAngles.y = Float(wallAngle(wall))
        node.name = "wall"
        return node
    }

    /// SceneKit's rotation about +Y turns local +x into (cos θ, 0, -sin θ).
    private static func wallAngle(_ w: Wall) -> Double {
        atan2(-(w.end.z - w.start.z), w.end.x - w.start.x)
    }

    private static func openingNode(_ o: Opening, wall: Wall?, floorY: Double) -> SCNNode? {
        guard o.kind != .opening else { return nil } // empty passages stay as they are
        let isWindow = o.kind == .window
        let box = SCNBox(width: CGFloat(o.width), height: CGFloat(o.height),
                         length: wallThickness + 0.02, chamferRadius: 0.005)
        box.materials = [isWindow
            ? material(UIColor(red: 0.62, green: 0.82, blue: 0.95, alpha: 0.55), roughness: 0.05, metalness: 0.1)
            : material(UIColor(red: 0.45, green: 0.30, blue: 0.20, alpha: 1), roughness: 0.6)]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(o.center.x, FloorLevel.centerHeight(of: o, floorY: floorY), o.center.z)
        if let wall { node.eulerAngles.y = Float(wallAngle(wall)) }
        return node
    }

    private static func nearestWall(to o: Opening, in walls: [Wall]) -> Wall? {
        let p = Point2(x: o.center.x, z: o.center.z)
        return walls.min { a, b in
            let ma = Point2(x: (a.start.x + a.end.x) / 2, z: (a.start.z + a.end.z) / 2)
            let mb = Point2(x: (b.start.x + b.end.x) / 2, z: (b.start.z + b.end.z) / 2)
            return p.distance(to: ma) < p.distance(to: mb)
        }
    }

    // MARK: Furniture

    private static func furnitureNode(_ o: RoomObject, walls: [Wall], tables: [RoomObject], floorY: Double) -> SCNNode {
        let back = FurnitureBlueprint.backSide(of: o, walls: walls, tables: tables)
        let group = SCNNode()
        group.name = FurnitureNames.turkish(o.category)
        group.position = SCNVector3(o.center.x, FloorLevel.restingCenterHeight(of: o, floorY: floorY), o.center.z)
        group.eulerAngles.y = Float(o.yaw)

        for part in FurnitureBlueprint.parts(category: o.category, size: o.size, backSign: back) {
            let geometry: SCNGeometry
            switch part.shape {
            case .box:
                let r = CGFloat(min(part.size.x, part.size.y, part.size.z) * 0.12)
                geometry = SCNBox(width: CGFloat(part.size.x), height: CGFloat(part.size.y),
                                  length: CGFloat(part.size.z), chamferRadius: min(r, 0.03))
            case .cylinder:
                geometry = SCNCylinder(radius: CGFloat(part.size.x / 2), height: CGFloat(part.size.y))
            }
            geometry.materials = [material(for: part.material)]
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(part.center.x, part.center.y, part.center.z)
            group.addChildNode(node)
        }
        return group
    }

    private static func material(for m: FurniturePart.Material) -> SCNMaterial {
        switch m {
        case .wood: material(UIColor(red: 0.72, green: 0.53, blue: 0.34, alpha: 1), roughness: 0.6)
        case .darkWood: material(UIColor(red: 0.36, green: 0.24, blue: 0.16, alpha: 1), roughness: 0.6)
        case .fabric: material(UIColor(red: 0.47, green: 0.52, blue: 0.56, alpha: 1), roughness: 0.95)
        case .cushion: material(UIColor(red: 0.62, green: 0.66, blue: 0.69, alpha: 1), roughness: 0.95)
        case .linen: material(UIColor(red: 0.93, green: 0.91, blue: 0.86, alpha: 1), roughness: 0.9)
        case .metal: material(UIColor(white: 0.75, alpha: 1), roughness: 0.3, metalness: 0.9)
        case .white: material(UIColor(white: 0.97, alpha: 1), roughness: 0.5)
        case .dark: material(UIColor(white: 0.12, alpha: 1), roughness: 0.3)
        case .glass: material(UIColor(red: 0.70, green: 0.85, blue: 0.95, alpha: 0.6), roughness: 0.05)
        case .ceramic: material(UIColor(white: 0.98, alpha: 1), roughness: 0.15)
        case .stone: material(UIColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1), roughness: 0.9)
        }
    }

    private static func material(_ color: UIColor, roughness: CGFloat, metalness: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        if color.cgColor.alpha < 1 {
            m.transparency = color.cgColor.alpha
            m.blendMode = .alpha
        }
        return m
    }

    // MARK: Lighting & camera

    private static func addLights(to root: SCNNode) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 450
        root.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 900
        sun.light!.castsShadow = true
        sun.light!.shadowMode = .deferred
        sun.light!.shadowColor = UIColor(white: 0, alpha: 0.35)
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        root.addChildNode(sun)
    }

    /// Camera that frames the whole room, either from above (plan) or at an angle.
    static func cameraNode(for scan: RoomScan, topDown: Bool) -> SCNNode {
        let pts = scan.walls.flatMap { [$0.start, $0.end] }
        let xs = pts.map(\.x), zs = pts.map(\.z)
        let cx = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
        let cz = ((zs.min() ?? 0) + (zs.max() ?? 0)) / 2
        let span = max((xs.max() ?? 1) - (xs.min() ?? 0), (zs.max() ?? 1) - (zs.min() ?? 0), 2)
        let height = scan.walls.map(\.height).max() ?? 2.5

        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.zNear = 0.05
        camera.zFar = 100
        let node = SCNNode()
        node.camera = camera
        if topDown {
            node.position = SCNVector3(cx, height + span * 1.1, cz)
            node.look(at: SCNVector3(cx, 0, cz), up: SCNVector3(0, 0, -1), localFront: SCNVector3(0, 0, -1))
        } else {
            node.position = SCNVector3(cx + span * 0.6, height + span * 0.5, cz + span * 0.9)
            node.look(at: SCNVector3(cx, height * 0.3, cz))
        }
        return node
    }
}
