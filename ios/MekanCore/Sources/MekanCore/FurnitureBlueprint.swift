import Foundation

/// One primitive of a procedurally built furniture piece, in the object's local
/// frame: origin at the box center, x = width, y = up, z = depth.
public struct FurniturePart: Equatable, Sendable {
    public enum Shape: Sendable { case box, cylinder }
    public enum Material: Sendable { case wood, darkWood, fabric, cushion, metal, white, dark, glass, ceramic, stone, linen }

    public var shape: Shape
    public var center: Point3
    /// Box: width/height/depth. Cylinder: x = diameter, y = height (z ignored).
    public var size: Point3
    public var material: Material

    /// Axis-aligned size of the part (cylinders are as wide as deep).
    public var extent: Point3 {
        shape == .cylinder ? Point3(x: size.x, y: size.y, z: size.x) : size
    }
}

/// Builds recognizable furniture from simple shapes, sized exactly to RoomPlan's
/// detected bounding box. `backSign` (+1 / -1) says which local z side is the back.
public enum FurnitureBlueprint {
    public static func parts(category: String, size: Point3, backSign: Double) -> [FurniturePart] {
        let b = backSign >= 0 ? 1.0 : -1.0
        let w = size.x, h = size.y, d = size.z
        let bottom = -h / 2

        func box(_ cx: Double, _ cy: Double, _ cz: Double, _ sx: Double, _ sy: Double, _ sz: Double,
                 _ m: FurniturePart.Material) -> FurniturePart {
            FurniturePart(shape: .box, center: Point3(x: cx, y: cy, z: cz), size: Point3(x: sx, y: sy, z: sz), material: m)
        }
        func leg(_ cx: Double, _ cz: Double, height: Double, diameter: Double, _ m: FurniturePart.Material) -> FurniturePart {
            FurniturePart(shape: .cylinder, center: Point3(x: cx, y: bottom + height / 2, z: cz),
                          size: Point3(x: diameter, y: height, z: diameter), material: m)
        }
        func fourLegs(height: Double, inset: Double, diameter: Double, _ m: FurniturePart.Material) -> [FurniturePart] {
            let ix = max(w / 2 - inset, 0), iz = max(d / 2 - inset, 0)
            return [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map { leg($0.0 * ix, $0.1 * iz, height: height, diameter: diameter, m) }
        }
        /// A slab of `thickness` placed flush with the back (s = b) or front (s = -b).
        func zFlush(_ s: Double, _ thickness: Double) -> Double { s * (d / 2 - thickness / 2) }

        switch category {
        case "table":
            let t = min(0.04, h * 0.1)
            let legD = min(0.05, w / 4, d / 4)
            return [box(0, h / 2 - t / 2, 0, w, t, d, .wood)]
                + fourLegs(height: h - t, inset: legD / 2 + min(0.04, w / 8), diameter: legD, .darkWood)

        case "chair":
            let seatTop = min(0.46, h * 0.5), seatT = min(0.05, seatTop * 0.2)
            let backT = min(0.05, d * 0.15)
            let legD = min(0.04, w / 5, d / 5)
            return [
                box(0, bottom + seatTop - seatT / 2, 0, w, seatT, d, .cushion),
                box(0, bottom + seatTop + (h - seatTop) / 2, zFlush(b, backT), w, h - seatTop, backT, .wood),
            ] + fourLegs(height: seatTop - seatT, inset: legD / 2 + 0.01, diameter: legD, .darkWood)

        case "sofa":
            let baseH = h * 0.42, seatH = min(0.12, h * 0.15)
            let backD = min(0.22, d * 0.28), arm = min(0.18, w * 0.12)
            let armH = h * 0.68
            let seatD = d - backD
            return [
                box(0, bottom + baseH / 2, 0, w, baseH, d, .fabric),
                box(0, bottom + baseH + seatH / 2, zFlush(-b, seatD), w - 2 * arm, seatH, seatD, .cushion),
                box(0, 0, zFlush(b, backD), w, h, backD, .fabric),
                box(-(w / 2 - arm / 2), bottom + armH / 2, 0, arm, armH, d, .fabric),
                box(w / 2 - arm / 2, bottom + armH / 2, 0, arm, armH, d, .fabric),
            ]

        case "bed":
            let frameH = h * 0.35, mattressH = min(0.25, h * 0.3)
            let headT = min(0.08, d * 0.05)
            let mattressD = d - headT - 0.04
            let pillowW = w * 0.38, pillowD = min(0.35, d * 0.18), pillowH = min(0.1, h - frameH - mattressH)
            let pillowZ = b * (d / 2 - headT - pillowD / 2 - 0.03)
            return [
                box(0, bottom + frameH / 2, 0, w, frameH, d, .wood),
                box(0, bottom + frameH + mattressH / 2, zFlush(-b, mattressD) , w - 0.04, mattressH, mattressD, .linen),
                box(0, 0, zFlush(b, headT), w, h, headT, .darkWood),
                box(-w / 4, bottom + frameH + mattressH + pillowH / 2, pillowZ, pillowW, pillowH, pillowD, .white),
                box(w / 4, bottom + frameH + mattressH + pillowH / 2, pillowZ, pillowW, pillowH, pillowD, .white),
            ]

        case "storage":
            let doorT = min(0.02, d * 0.05)
            let bodyD = d - doorT
            let doorW = w / 2 - 0.01
            return [
                box(0, 0, zFlush(b, bodyD), w, h, bodyD, .wood),
                box(-w / 4, 0, zFlush(-b, doorT), doorW, h - 0.02, doorT, .white),
                box(w / 4, 0, zFlush(-b, doorT), doorW, h - 0.02, doorT, .white),
            ]

        case "refrigerator", "stove", "oven", "dishwasher", "washerDryer":
            let panelT = min(0.02, d * 0.05)
            let bodyD = d - panelT
            let panel: FurniturePart = category == "stove"
                ? box(0, h / 2 - min(0.01, h * 0.02) / 2, 0, w * 0.8, min(0.01, h * 0.02), d * 0.8, .dark) // cooktop
                : box(0, category == "refrigerator" ? h * 0.1 : -h * 0.05, zFlush(-b, panelT),
                      w * 0.85, h * 0.6, panelT, category == "refrigerator" ? .metal : .dark)
            return [box(0, category == "stove" ? -min(0.01, h * 0.02) / 2 : 0,
                        category == "stove" ? 0 : zFlush(b, bodyD),
                        w, category == "stove" ? h - min(0.01, h * 0.02) : h,
                        category == "stove" ? d : bodyD, .white), panel]

        case "sink", "toilet", "bathtub":
            let basinH = min(0.15, h * 0.4)
            return [
                box(0, -basinH / 2, 0, w, h - basinH, d, .ceramic),
                box(0, h / 2 - basinH / 2, 0, w * 0.8, basinH, d * 0.75, .glass),
                box(0, h / 2 - basinH / 2, zFlush(b, d * 0.1), w, basinH, d * 0.1, .ceramic),
            ]

        case "fireplace":
            return [
                box(0, 0, 0, w, h, d * 0.9, .stone),
                box(0, bottom + h * 0.3, zFlush(-b, d * 0.1), w * 0.55, h * 0.5, d * 0.1, .dark),
            ]

        case "television":
            let panelT = min(0.06, d)
            let standH = min(0.08, h * 0.15)
            return [
                box(0, standH / 2, zFlush(b, panelT), w, h - standH, panelT, .dark),
                box(0, bottom + standH / 2, 0, w * 0.3, standH, d * 0.6, .metal),
            ]

        case "stairs":
            let n = max(2, Int((h / 0.18).rounded()))
            let rise = h / Double(n), run = d / Double(n)
            // Steps climb toward the back.
            return (0..<n).map { i in
                let sh = rise * Double(i + 1)
                let cz = -b * (d / 2 - run * (Double(i) + 0.5))
                return box(0, bottom + sh / 2, cz, w, sh, run, .wood)
            }

        default:
            return [box(0, 0, 0, w, h, d, .white)]
        }
    }

    /// Which local z side (+1 / -1) is the object's back.
    /// Chairs near a table turn their back away from it; everything else backs onto the nearest wall.
    public static func backSide(of object: RoomObject, walls: [Wall], tables: [RoomObject]) -> Double {
        let c = Point2(x: object.center.x, z: object.center.z)
        // Local +z in world: rotation about +Y maps (0,0,1) to (sin θ, 0, cos θ).
        let dir = Point2(x: sin(object.yaw), z: cos(object.yaw))
        let half = object.size.z / 2
        let plus = Point2(x: c.x + dir.x * half, z: c.z + dir.z * half)
        let minus = Point2(x: c.x - dir.x * half, z: c.z - dir.z * half)

        if object.category == "chair",
           let table = tables.min(by: { distance(c, $0) < distance(c, $1) }),
           distance(c, table) < 1.5 {
            let t = Point2(x: table.center.x, z: table.center.z)
            return plus.distance(to: t) > minus.distance(to: t) ? 1 : -1
        }

        guard !walls.isEmpty else { return -1 }
        let dPlus = walls.map { segmentDistance(plus, $0) }.min()!
        let dMinus = walls.map { segmentDistance(minus, $0) }.min()!
        return dPlus < dMinus ? 1 : -1
    }

    private static func distance(_ p: Point2, _ o: RoomObject) -> Double {
        p.distance(to: Point2(x: o.center.x, z: o.center.z))
    }

    static func segmentDistance(_ p: Point2, _ w: Wall) -> Double {
        let vx = w.end.x - w.start.x, vz = w.end.z - w.start.z
        let len2 = vx * vx + vz * vz
        guard len2 > 0 else { return p.distance(to: w.start) }
        let t = max(0, min(1, ((p.x - w.start.x) * vx + (p.z - w.start.z) * vz) / len2))
        return p.distance(to: Point2(x: w.start.x + t * vx, z: w.start.z + t * vz))
    }
}
