import SceneKit
import UIKit
import MekanCore

/// Builds a furnished SceneKit scene from a RoomScan: textured floor and walls with
/// skirting, doors, windows, procedurally modeled furniture at the detected sizes,
/// and soft image-based lighting with shadows.
enum RoomSceneBuilder {
    static let wallThickness: CGFloat = 0.08

    static func scene(for scan: RoomScan, design: ScanDesign = ScanDesign()) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        root.addChildNode(floor(for: scan, type: design.floor))
        let center = PlanGeometry.centroid(of: scan.walls)
        for wall in scan.walls {
            root.addChildNode(wallNode(wall, color: design.wallColor))
            root.addChildNode(skirting(for: wall, roomCenter: center))
        }

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

        scene.lightingEnvironment.contents = TextureFactory.environment()
        scene.lightingEnvironment.intensity = 1.3
        addLights(to: root, scan: scan)
        return scene
    }

    // MARK: Structure

    /// Applies a new wall color / floor to an already built scene (live preview).
    static func apply(_ design: ScanDesign, to scene: SCNScene) {
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "wall", let box = node.geometry as? SCNBox {
                box.materials = [wallMaterial(design.wallColor, size: max(box.width, box.height))]
            } else if node.name == "floor", let shape = node.geometry {
                let (lo, hi) = shape.boundingBox
                shape.materials = [floorMaterial(design.floor, span: CGFloat(max(hi.x - lo.x, hi.y - lo.y)))]
            }
        }
    }

    static func wallMaterial(_ color: WallColor, size: CGFloat) -> SCNMaterial {
        let c = color.rgb
        return textured(.wall, UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1), repeat: size / 2, roughness: 0.9)
    }

    static func floorMaterial(_ type: FloorType, span: CGFloat) -> SCNMaterial {
        switch type {
        case .oakParquet:
            return textured(.parquet, UIColor(red: 0.74, green: 0.58, blue: 0.42, alpha: 1), repeat: span, roughness: 0.55)
        case .walnutParquet:
            return textured(.parquet, UIColor(red: 0.42, green: 0.29, blue: 0.20, alpha: 1), repeat: span, roughness: 0.5)
        case .whiteOakParquet:
            return textured(.parquet, UIColor(red: 0.86, green: 0.78, blue: 0.66, alpha: 1), repeat: span, roughness: 0.6)
        case .greyTile:
            return textured(.tile, UIColor(red: 0.70, green: 0.70, blue: 0.69, alpha: 1), repeat: span, roughness: 0.3)
        case .marble:
            return textured(.marble, UIColor(red: 0.94, green: 0.93, blue: 0.91, alpha: 1), repeat: span / 2, roughness: 0.12)
        case .carpet:
            return textured(.fabric, UIColor(red: 0.58, green: 0.55, blue: 0.50, alpha: 1), repeat: span * 3, roughness: 1)
        }
    }

    private static func floor(for scan: RoomScan, type: FloorType) -> SCNNode {
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
        let span = max(path.bounds.width, path.bounds.height)
        // Floor textures cover 1 m; repeat once per meter.
        shape.materials = [floorMaterial(type, span: span)]
        let node = SCNNode(geometry: shape)
        node.eulerAngles.x = -.pi / 2
        node.position.y = -0.01
        node.name = "floor"
        return node
    }

    private static func wallNode(_ wall: Wall, color: WallColor) -> SCNNode {
        let box = SCNBox(width: CGFloat(wall.length), height: CGFloat(wall.height), length: wallThickness, chamferRadius: 0)
        box.materials = [wallMaterial(color, size: CGFloat(max(wall.length, wall.height)))]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3((wall.start.x + wall.end.x) / 2, wall.height / 2, (wall.start.z + wall.end.z) / 2)
        node.eulerAngles.y = Float(wallAngle(wall))
        node.name = "wall"
        return node
    }

    /// 8 cm white skirting board on the room side of each wall.
    private static func skirting(for wall: Wall, roomCenter: Point2) -> SCNNode {
        let thickness = 0.015, height = 0.08
        let mid = Point2(x: (wall.start.x + wall.end.x) / 2, z: (wall.start.z + wall.end.z) / 2)
        let offset = Double(wallThickness) / 2 + thickness / 2
        let outside = PlanGeometry.labelAnchor(for: wall, roomCenter: roomCenter, offset: offset)
        let inside = Point2(x: 2 * mid.x - outside.x, z: 2 * mid.z - outside.z)
        let box = SCNBox(width: CGFloat(wall.length), height: CGFloat(height), length: CGFloat(thickness), chamferRadius: 0.003)
        box.materials = [material(UIColor(white: 0.97, alpha: 1), roughness: 0.4)]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(inside.x, height / 2, inside.z)
        node.eulerAngles.y = Float(wallAngle(wall))
        return node
    }

    /// SceneKit's rotation about +Y turns local +x into (cos θ, 0, -sin θ).
    private static func wallAngle(_ w: Wall) -> Double {
        atan2(-(w.end.z - w.start.z), w.end.x - w.start.x)
    }

    private static func openingNode(_ o: Opening, wall: Wall?, floorY: Double) -> SCNNode? {
        guard o.kind != .opening else { return nil } // empty passages stay as they are
        let isWindow = o.kind == .window
        let group = SCNNode()
        group.position = SCNVector3(o.center.x, FloorLevel.centerHeight(of: o, floorY: floorY), o.center.z)
        if let wall { group.eulerAngles.y = Float(wallAngle(wall)) }

        let depth = wallThickness + 0.02
        let frame: CGFloat = 0.05
        // Frame: four bars around the opening.
        let frameMat = isWindow ? material(UIColor(white: 0.96, alpha: 1), roughness: 0.4)
                                : textured(.wood, UIColor(red: 0.42, green: 0.28, blue: 0.18, alpha: 1), repeat: 1, roughness: 0.5)
        let w = CGFloat(o.width), h = CGFloat(o.height)
        let bars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0, h / 2 - frame / 2, w, frame), (-w / 2 + frame / 2, 0, frame, h), (w / 2 - frame / 2, 0, frame, h),
        ] + (isWindow ? [(0, -h / 2 + frame / 2, w, frame)] : [])
        for (x, y, bw, bh) in bars {
            let bar = SCNBox(width: bw, height: bh, length: depth, chamferRadius: 0.005)
            bar.materials = [frameMat]
            let n = SCNNode(geometry: bar); n.position = SCNVector3(x, y, 0)
            group.addChildNode(n)
        }
        // Panel: glass for windows, a wooden leaf for doors.
        let panel = SCNBox(width: w - 2 * frame, height: isWindow ? h - 2 * frame : h - frame,
                           length: isWindow ? 0.01 : 0.04, chamferRadius: 0.003)
        panel.materials = [isWindow
            ? material(UIColor(red: 0.70, green: 0.85, blue: 0.95, alpha: 0.35), roughness: 0.02, metalness: 0.2)
            : textured(.wood, UIColor(red: 0.55, green: 0.38, blue: 0.25, alpha: 1), repeat: 1.5, roughness: 0.5)]
        let pn = SCNNode(geometry: panel)
        pn.position = SCNVector3(0, isWindow ? 0 : -frame / 2, 0)
        group.addChildNode(pn)
        return group
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
        group.name = o.turkishName
        group.position = SCNVector3(o.center.x, FloorLevel.restingCenterHeight(of: o, floorY: floorY), o.center.z)
        group.eulerAngles.y = Float(o.yaw)

        for part in FurnitureBlueprint.parts(category: o.category, size: o.size, backSign: back,
                                             attributes: o.attributes ?? []) {
            let geometry: SCNGeometry
            switch part.shape {
            case .box:
                let smallest = min(part.size.x, part.size.y, part.size.z)
                let box = SCNBox(width: CGFloat(part.size.x), height: CGFloat(part.size.y),
                                 length: CGFloat(part.size.z), chamferRadius: CGFloat(smallest * min(part.rounding, 0.5)))
                box.chamferSegmentCount = part.rounding > 0.2 ? 8 : 3
                geometry = box
            case .cylinder:
                let c = SCNCylinder(radius: CGFloat(part.size.x / 2), height: CGFloat(part.size.y))
                c.radialSegmentCount = 24
                geometry = c
            }
            geometry.materials = [material(for: part)]
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(part.center.x, part.center.y, part.center.z)
            node.castsShadow = true
            group.addChildNode(node)
        }
        return group
    }

    private static func material(for part: FurniturePart) -> SCNMaterial {
        // Texture repeats roughly every 60 cm of the part's longest side.
        let r = CGFloat(max(part.size.x, part.size.y, part.size.z) / 0.6)
        switch part.material {
        case .wood: return textured(.wood, UIColor(red: 0.72, green: 0.53, blue: 0.34, alpha: 1), repeat: r, roughness: 0.55)
        case .darkWood: return textured(.wood, UIColor(red: 0.33, green: 0.22, blue: 0.15, alpha: 1), repeat: r, roughness: 0.5)
        case .fabric: return textured(.fabric, UIColor(red: 0.44, green: 0.49, blue: 0.53, alpha: 1), repeat: r * 2, roughness: 0.95)
        case .cushion: return textured(.fabric, UIColor(red: 0.58, green: 0.62, blue: 0.65, alpha: 1), repeat: r * 2, roughness: 0.95)
        case .linen: return textured(.fabric, UIColor(red: 0.94, green: 0.92, blue: 0.87, alpha: 1), repeat: r * 2, roughness: 0.9)
        case .metal: return material(UIColor(white: 0.78, alpha: 1), roughness: 0.25, metalness: 0.95)
        case .white: return material(UIColor(white: 0.96, alpha: 1), roughness: 0.45)
        case .dark: return material(UIColor(white: 0.08, alpha: 1), roughness: 0.2, metalness: 0.3)
        case .glass: return material(UIColor(red: 0.70, green: 0.85, blue: 0.95, alpha: 0.5), roughness: 0.03, metalness: 0.2)
        case .ceramic: return material(UIColor(white: 0.98, alpha: 1), roughness: 0.12)
        case .stone: return textured(.stone, UIColor(red: 0.55, green: 0.53, blue: 0.50, alpha: 1), repeat: r, roughness: 0.9)
        }
    }

    private static func textured(_ kind: TextureFactory.Kind, _ color: UIColor, repeat count: CGFloat,
                                 roughness: CGFloat) -> SCNMaterial {
        let m = material(color, roughness: roughness)
        m.diffuse.contents = TextureFactory.image(kind, color: color)
        let s = Float(max(count, 1))
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(s, s, 1)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.mipFilter = .linear
        return m
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
            m.writesToDepthBuffer = false
        }
        return m
    }

    // MARK: Lighting & camera

    private static func addLights(to root: SCNNode, scan: RoomScan) {
        let (cx, cz, span, height) = bounds(of: scan)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 120
        root.addChildNode(ambient)

        // Daylight with soft shadows covering the whole room.
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 650
        sun.light!.color = UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1)
        sun.light!.castsShadow = true
        sun.light!.shadowMode = .deferred
        sun.light!.shadowColor = UIColor(white: 0, alpha: 0.45)
        sun.light!.shadowRadius = 6
        sun.light!.shadowSampleCount = 16
        sun.light!.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light!.orthographicScale = CGFloat(span)
        sun.light!.automaticallyAdjustsShadowProjection = true
        sun.position = SCNVector3(cx, height * 3, cz)
        sun.eulerAngles = SCNVector3(-Float.pi / 2.6, Float.pi / 6, 0)
        root.addChildNode(sun)

        // Warm ceiling lamp in the middle of the room.
        let lamp = SCNNode()
        lamp.light = SCNLight()
        lamp.light!.type = .omni
        lamp.light!.intensity = 350
        lamp.light!.color = UIColor(red: 1.0, green: 0.88, blue: 0.72, alpha: 1)
        lamp.light!.attenuationStartDistance = 1
        lamp.light!.attenuationEndDistance = CGFloat(span * 1.2)
        lamp.position = SCNVector3(cx, height - 0.15, cz)
        root.addChildNode(lamp)
    }

    private static func bounds(of scan: RoomScan) -> (cx: Double, cz: Double, span: Double, height: Double) {
        let pts = scan.walls.flatMap { [$0.start, $0.end] }
        let xs = pts.map(\.x), zs = pts.map(\.z)
        let cx = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
        let cz = ((zs.min() ?? 0) + (zs.max() ?? 0)) / 2
        let span = max((xs.max() ?? 1) - (xs.min() ?? 0), (zs.max() ?? 1) - (zs.min() ?? 0), 2)
        let height = scan.walls.map(\.height).max() ?? 2.5
        return (cx, cz, span, height)
    }

    /// Camera that frames the whole room, either from above (plan) or at an angle.
    static func cameraNode(for scan: RoomScan, topDown: Bool) -> SCNNode {
        let (cx, cz, span, height) = bounds(of: scan)

        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.zNear = 0.05
        camera.zFar = 100
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = 0.2
        // Contact shadows in corners and under furniture.
        camera.screenSpaceAmbientOcclusionIntensity = 1.4
        camera.screenSpaceAmbientOcclusionRadius = 0.25
        camera.screenSpaceAmbientOcclusionNormalThreshold = 0.3
        camera.screenSpaceAmbientOcclusionDepthThreshold = 0.2

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
