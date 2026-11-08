import Foundation
import RoomPlan
import simd
import MekanCore

/// Converts RoomPlan's CapturedRoom into our stable RoomScan (v1) format.
enum RoomScanConverter {
    static func convert(_ room: CapturedRoom, name: String) -> RoomScan {
        let walls = room.walls.map { surface -> Wall in
            let (start, end) = endpoints(of: surface)
            return Wall(id: surface.identifier.uuidString,
                        start: start, end: end,
                        height: Double(surface.dimensions.y))
        }

        let openings =
            room.doors.map { opening($0, kind: .door) } +
            room.windows.map { opening($0, kind: .window) } +
            room.openings.map { opening($0, kind: .opening) }

        let objects = room.objects.map { obj -> RoomObject in
            let t = obj.transform
            return RoomObject(id: obj.identifier.uuidString,
                              category: categoryName(obj.category),
                              center: point3(t.columns.3),
                              size: Point3(x: Double(obj.dimensions.x),
                                           y: Double(obj.dimensions.y),
                                           z: Double(obj.dimensions.z)),
                              yaw: yaw(of: t))
        }

        return RoomScan(name: name, walls: walls, openings: openings, objects: objects,
                        floorY: floorLevel(of: room))
    }

    /// Floor height in RoomPlan's frame (which starts at the phone, not the floor).
    /// Prefers the detected floor surface, else the median bottom edge of the walls.
    static func floorLevel(of room: CapturedRoom) -> Double? {
        if let floor = room.floors.first {
            return Double(floor.transform.columns.3.y)
        }
        let bottoms = room.walls
            .map { Double($0.transform.columns.3.y - $0.dimensions.y / 2) }
            .sorted()
        guard !bottoms.isEmpty else { return nil }
        return bottoms[bottoms.count / 2]
    }

    /// A wall surface is a plane: its local X axis runs along the wall and
    /// `dimensions.x` is its length, centered on the transform's origin.
    static func endpoints(of surface: CapturedRoom.Surface) -> (Point2, Point2) {
        let t = surface.transform
        let center = SIMD2<Float>(t.columns.3.x, t.columns.3.z)
        var dir = SIMD2<Float>(t.columns.0.x, t.columns.0.z)
        if simd_length(dir) > 0 { dir = simd_normalize(dir) }
        let half = dir * (surface.dimensions.x / 2)
        let a = center - half, b = center + half
        return (Point2(x: Double(a.x), z: Double(a.y)), Point2(x: Double(b.x), z: Double(b.y)))
    }

    private static func opening(_ s: CapturedRoom.Surface, kind: OpeningKind) -> Opening {
        Opening(id: s.identifier.uuidString,
                kind: kind,
                wallId: s.parentIdentifier?.uuidString,
                center: point3(s.transform.columns.3),
                width: Double(s.dimensions.x),
                height: Double(s.dimensions.y))
    }

    private static func point3(_ c: SIMD4<Float>) -> Point3 {
        Point3(x: Double(c.x), y: Double(c.y), z: Double(c.z))
    }

    /// Rotation about +Y: column 0 is (cos θ, 0, -sin θ).
    private static func yaw(of t: simd_float4x4) -> Double {
        Double(atan2(-t.columns.0.z, t.columns.0.x))
    }

    private static func categoryName(_ c: CapturedRoom.Object.Category) -> String {
        // Enum cases print as their names: "sofa", "table", "washerDryer"…
        String(describing: c)
    }
}
