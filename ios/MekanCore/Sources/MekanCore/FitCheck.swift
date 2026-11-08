import Foundation

/// Outer dimensions of a piece of furniture the user wants to buy (meters).
public struct FurnitureSize: Equatable, Sendable {
    public var width: Double, depth: Double, height: Double
    public init(width: Double, depth: Double, height: Double) {
        self.width = width; self.depth = depth; self.height = height
    }
}

public enum DoorPassage: Equatable, Sendable {
    /// Carried upright or on its side without tilting.
    case straight
    /// Only fits through the frame at an angle.
    case tilted
    case no
}

/// A stretch of wall where the item can stand.
public struct FitSpot: Equatable, Sendable {
    public let wallId: String
    public let start: Point2
    public let end: Point2
    public let freeLength: Double
    /// At least `walkway` meters stay free in front of the item.
    public let leavesWalkway: Bool
}

public struct FitReport: Equatable, Sendable {
    public let fitsUnderCeiling: Bool
    /// Best result over all doors; nil when the scan has no doors.
    public let door: DoorPassage?
    public let spots: [FitSpot]
}

/// "Sığar mı?": will a piece of furniture get through the door, fit under the ceiling,
/// and where along the walls is there room for it.
public enum FitCheck {
    /// Clearance kept on both sides of a doorway (door frame, swing).
    public static let doorClearance = 0.1
    /// Furniture within this distance of a wall is treated as standing against it.
    public static let wallProximity = 0.3

    public static func check(_ item: FurnitureSize, in scan: RoomScan, walkway: Double = 0.6) -> FitReport {
        let ceiling = RoomMeasurements(scan: scan).ceilingHeight
        let floorY = scan.estimatedFloorY
        let doors = scan.openings.filter { $0.kind == .door }
        let door: DoorPassage? = doors.isEmpty ? nil : doors.map { passage(item, door: $0) }.min { rank($0) < rank($1) }

        let center = PlanGeometry.centroid(of: scan.walls)
        let allPoints = scan.walls.flatMap { [$0.start, $0.end] }
        var spots: [FitSpot] = []

        for wall in scan.walls where wall.length > 0 {
            let L = wall.length
            let dir = Point2(x: (wall.end.x - wall.start.x) / L, z: (wall.end.z - wall.start.z) / L)
            func along(_ p: Point2) -> Double { (p.x - wall.start.x) * dir.x + (p.z - wall.start.z) * dir.z }

            var blocked: [(Double, Double)] = []
            for o in scan.openings where belongs(o, to: wall, walls: scan.walls) {
                let t = along(Point2(x: o.center.x, z: o.center.z))
                switch o.kind {
                case .door, .opening:
                    blocked.append((t - o.width / 2 - doorClearance, t + o.width / 2 + doorClearance))
                case .window:
                    let sill = FloorLevel.centerHeight(of: o, floorY: floorY) - o.height / 2
                    if item.height > sill { blocked.append((t - o.width / 2, t + o.width / 2)) }
                }
            }
            for obj in scan.objects {
                let c = Point2(x: obj.center.x, z: obj.center.z)
                let reach = max(obj.size.x, obj.size.z) / 2
                guard FurnitureBlueprint.segmentDistance(c, wall) <= reach + wallProximity else { continue }
                let t = along(c)
                blocked.append((t - reach, t + reach))
            }

            // Inward normal and how deep the room is in front of this wall.
            var n = Point2(x: -dir.z, z: dir.x)
            let mid = Point2(x: (wall.start.x + wall.end.x) / 2, z: (wall.start.z + wall.end.z) / 2)
            if n.x * (center.x - mid.x) + n.z * (center.z - mid.z) < 0 { n = Point2(x: -n.x, z: -n.z) }
            let roomDepth = allPoints.map { ($0.x - wall.start.x) * n.x + ($0.z - wall.start.z) * n.z }.max() ?? 0

            for (a, b) in freeIntervals(length: L, blocked: blocked) where b - a >= item.width - 1e-9 {
                spots.append(FitSpot(wallId: wall.id,
                                     start: Point2(x: wall.start.x + dir.x * a, z: wall.start.z + dir.z * a),
                                     end: Point2(x: wall.start.x + dir.x * b, z: wall.start.z + dir.z * b),
                                     freeLength: b - a,
                                     leavesWalkway: roomDepth - item.depth >= walkway - 1e-9))
            }
        }

        return FitReport(fitsUnderCeiling: item.height <= ceiling + 1e-9, door: door, spots: spots)
    }

    /// Can the item pass through this door? The longest side goes through the opening;
    /// the other two must fit the frame, upright or at an angle.
    static func passage(_ item: FurnitureSize, door: Opening) -> DoorPassage {
        let dims = [item.width, item.depth, item.height].sorted()
        let a = dims[0], b = dims[1]
        let w = door.width, h = door.height
        if (a <= w && b <= h) || (a <= h && b <= w) { return .straight }
        // An a × b cross-section rotated by θ needs b·cosθ + a·sinθ ≤ h and b·sinθ + a·cosθ ≤ w.
        for step in 0...180 {
            let t = Double(step) / 180 * .pi / 2
            if b * cos(t) + a * sin(t) <= h + 1e-9 && b * sin(t) + a * cos(t) <= w + 1e-9 { return .tilted }
        }
        return .no
    }

    private static func rank(_ p: DoorPassage) -> Int {
        switch p {
        case .straight: 0
        case .tilted: 1
        case .no: 2
        }
    }

    /// Opening is on this wall: by id, or (older data) the nearest wall within 30 cm.
    private static func belongs(_ o: Opening, to wall: Wall, walls: [Wall]) -> Bool {
        if let id = o.wallId { return id == wall.id }
        let p = Point2(x: o.center.x, z: o.center.z)
        guard let nearest = walls.min(by: { FurnitureBlueprint.segmentDistance(p, $0) < FurnitureBlueprint.segmentDistance(p, $1) })
        else { return false }
        return nearest.id == wall.id && FurnitureBlueprint.segmentDistance(p, wall) <= 0.3
    }

    /// [0, length] minus the blocked ranges, as sorted free intervals.
    static func freeIntervals(length: Double, blocked: [(Double, Double)]) -> [(Double, Double)] {
        var free: [(Double, Double)] = []
        var cursor = 0.0
        for (s, e) in blocked.map({ (max(0, $0.0), min(length, $0.1)) }).filter({ $0.0 < $0.1 }).sorted(by: { $0.0 < $1.0 }) {
            if s > cursor { free.append((cursor, s)) }
            cursor = max(cursor, e)
        }
        if cursor < length { free.append((cursor, length)) }
        return free
    }
}
