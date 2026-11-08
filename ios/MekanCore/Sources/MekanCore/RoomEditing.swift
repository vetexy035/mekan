import Foundation

/// Manual corrections to a scan. Every operation returns a new scan and leaves
/// the input untouched; invalid requests return the scan unchanged.
public enum RoomEditing {
    /// Sets a wall to a measured length by stretching the whole room along that wall's
    /// direction (from its start corner). Parallel walls follow, so rectangles stay
    /// rectangles; doors, windows and furniture move with the stretch but keep their size.
    public static func setLength(of wallId: String, to newLength: Double, in scan: RoomScan) -> RoomScan {
        guard let wall = scan.walls.first(where: { $0.id == wallId }),
              wall.length > 0.01, newLength > 0.01 else { return scan }
        let k = newLength / wall.length
        let dir = Point2(x: (wall.end.x - wall.start.x) / wall.length, z: (wall.end.z - wall.start.z) / wall.length)
        let o = wall.start
        func stretch(_ x: Double, _ z: Double) -> (Double, Double) {
            let along = (x - o.x) * dir.x + (z - o.z) * dir.z
            let shift = along * (k - 1)
            return (x + dir.x * shift, z + dir.z * shift)
        }

        var out = scan
        out.walls = scan.walls.map { w in
            var w = w
            let s = stretch(w.start.x, w.start.z), e = stretch(w.end.x, w.end.z)
            w.start = Point2(x: s.0, z: s.1); w.end = Point2(x: e.0, z: e.1)
            return w
        }
        out.openings = scan.openings.map { op in
            var op = op
            let c = stretch(op.center.x, op.center.z)
            op.center.x = c.0; op.center.z = c.1
            return op
        }
        out.objects = scan.objects.map { ob in
            var ob = ob
            let c = stretch(ob.center.x, ob.center.z)
            ob.center.x = c.0; ob.center.z = c.1
            return ob
        }
        return out
    }

    public static func setCeilingHeight(_ height: Double, in scan: RoomScan) -> RoomScan {
        guard height > 0.5 else { return scan }
        var out = scan
        for i in out.walls.indices { out.walls[i].height = height }
        return out
    }

    public static func move(objectId: String, to point: Point2, in scan: RoomScan) -> RoomScan {
        var out = scan
        guard let i = out.objects.firstIndex(where: { $0.id == objectId }) else { return scan }
        out.objects[i].center.x = point.x
        out.objects[i].center.z = point.z
        return out
    }

    public static func rotate(objectId: String, byDegrees degrees: Double, in scan: RoomScan) -> RoomScan {
        var out = scan
        guard let i = out.objects.firstIndex(where: { $0.id == objectId }) else { return scan }
        var yaw = out.objects[i].yaw + degrees * .pi / 180
        yaw = atan2(sin(yaw), cos(yaw)) // keep in (-π, π]
        out.objects[i].yaw = yaw
        return out
    }

    public static func deleteObject(_ id: String, in scan: RoomScan) -> RoomScan {
        var out = scan
        out.objects.removeAll { $0.id == id }
        return out
    }

    public static func deleteOpening(_ id: String, in scan: RoomScan) -> RoomScan {
        var out = scan
        out.openings.removeAll { $0.id == id }
        return out
    }

    // MARK: Hit testing (plan coordinates, meters)

    /// The smallest furniture footprint containing the point.
    public static func object(at p: Point2, in scan: RoomScan) -> RoomObject? {
        scan.objects
            .filter { o in
                let dx = p.x - o.center.x, dz = p.z - o.center.z
                let c = cos(o.yaw), s = sin(o.yaw)
                let lx = dx * c - dz * s, lz = dx * s + dz * c
                return abs(lx) <= o.size.x / 2 && abs(lz) <= o.size.z / 2
            }
            .min { $0.size.x * $0.size.z < $1.size.x * $1.size.z }
    }

    public static func wall(near p: Point2, in scan: RoomScan, tolerance: Double) -> Wall? {
        guard let w = scan.walls.min(by: { FurnitureBlueprint.segmentDistance(p, $0) < FurnitureBlueprint.segmentDistance(p, $1) }),
              FurnitureBlueprint.segmentDistance(p, w) <= tolerance else { return nil }
        return w
    }

    public static func opening(near p: Point2, in scan: RoomScan, tolerance: Double) -> Opening? {
        scan.openings
            .map { ($0, Point2(x: $0.center.x, z: $0.center.z).distance(to: p)) }
            .filter { $0.1 <= max(tolerance, $0.0.width / 2) }
            .min { $0.1 < $1.1 }?.0
    }
}
