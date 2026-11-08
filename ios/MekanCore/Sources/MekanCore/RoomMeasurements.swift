import Foundation

/// Derived room measurements (meters, square meters).
public struct RoomMeasurements: Equatable, Sendable {
    /// Longer side of the room, aligned to the dominant wall direction.
    public let length: Double
    /// Shorter side of the room.
    public let width: Double
    public let ceilingHeight: Double
    public let floorArea: Double
    /// True when walls did not form a closed loop and the area is the bounding box.
    public let isAreaEstimated: Bool
    public let perimeter: Double
    public let doorCount: Int
    public let windowCount: Int
    public let objectCount: Int

    /// Max gap (m) between wall endpoints that still counts as a connected corner.
    public static let cornerTolerance = 0.15

    public init(scan: RoomScan) {
        let walls = scan.walls
        perimeter = walls.reduce(0) { $0 + $1.length }
        ceilingHeight = walls.map(\.height).max() ?? 0
        doorCount = scan.openings.filter { $0.kind == .door }.count
        windowCount = scan.openings.filter { $0.kind == .window }.count
        objectCount = scan.objects.count

        let (a, b) = Self.alignedExtents(walls)
        length = max(a, b)
        width = min(a, b)

        if let polygon = Self.closedPolygon(walls) {
            floorArea = Self.shoelaceArea(polygon)
            isAreaEstimated = false
        } else {
            floorArea = a * b
            isAreaEstimated = !walls.isEmpty
        }
    }

    /// Bounding-box extents after rotating so the longest wall lies on the X axis.
    static func alignedExtents(_ walls: [Wall]) -> (Double, Double) {
        guard let longest = walls.max(by: { $0.length < $1.length }) else { return (0, 0) }
        let angle = atan2(longest.end.z - longest.start.z, longest.end.x - longest.start.x)
        let c = cos(-angle), s = sin(-angle)
        let points = walls.flatMap { [$0.start, $0.end] }.map {
            Point2(x: $0.x * c - $0.z * s, z: $0.x * s + $0.z * c)
        }
        let xs = points.map(\.x), zs = points.map(\.z)
        return ((xs.max()! - xs.min()!), (zs.max()! - zs.min()!))
    }

    /// Chains walls end-to-end (any order, either direction). Returns the corner
    /// polygon only if every wall is used and the chain closes on itself.
    static func closedPolygon(_ walls: [Wall]) -> [Point2]? {
        guard walls.count >= 3 else { return nil }
        var remaining = Array(walls.dropFirst())
        var points = [walls[0].start, walls[0].end]

        while !remaining.isEmpty {
            let current = points.last!
            guard let i = remaining.firstIndex(where: {
                $0.start.distance(to: current) <= cornerTolerance || $0.end.distance(to: current) <= cornerTolerance
            }) else { return nil }
            let w = remaining.remove(at: i)
            let useEnd = w.start.distance(to: current) <= w.end.distance(to: current)
            points.append(useEnd ? w.end : w.start)
        }

        guard points.last!.distance(to: points[0]) <= cornerTolerance else { return nil }
        points.removeLast()
        return points
    }

    static func shoelaceArea(_ p: [Point2]) -> Double {
        var sum = 0.0
        for i in p.indices {
            let a = p[i], b = p[(i + 1) % p.count]
            sum += a.x * b.z - b.x * a.z
        }
        return abs(sum) / 2
    }
}
