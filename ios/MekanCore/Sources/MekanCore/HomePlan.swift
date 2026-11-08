import Foundation

/// Several rooms scanned one after another in a single session, so they share one
/// coordinate system and can be drawn together as a home plan.
public struct HomePlan: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    /// Saved RoomScans belonging to this home, in scan order.
    public var roomIDs: [UUID]
    /// True when Apple's StructureBuilder aligned the rooms; false when the raw
    /// same-session coordinates were used because merging failed.
    public var mergedByStructureBuilder: Bool

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), roomIDs: [UUID],
                mergedByStructureBuilder: Bool = true) {
        self.id = id
        self.name = name
        self.createdAt = Date(timeIntervalSince1970: floor(createdAt.timeIntervalSince1970))
        self.roomIDs = roomIDs
        self.mergedByStructureBuilder = mergedByStructureBuilder
    }

    public func totalArea(rooms: [RoomScan]) -> Double {
        rooms.reduce(0) { $0 + RoomMeasurements(scan: $1).floorArea }
    }

    /// All rooms in one scan, only for drawing the combined plan.
    public static func mergedScan(name: String, rooms: [RoomScan]) -> RoomScan {
        RoomScan(name: name,
                 walls: rooms.flatMap(\.walls),
                 openings: rooms.flatMap(\.openings),
                 objects: rooms.flatMap(\.objects),
                 floorY: rooms.first?.floorY)
    }

    public struct RoomLabel: Equatable, Sendable {
        public let text: String
        public let position: Point2
    }

    /// "Salon · 12.0 m²" at the middle of each room.
    public static func roomLabels(rooms: [RoomScan]) -> [RoomLabel] {
        rooms.map { r in
            RoomLabel(text: "\(r.name) · \(String(format: "%.1f", RoomMeasurements(scan: r).floorArea)) m²",
                      position: PlanGeometry.centroid(of: r.walls))
        }
    }

    /// Bounding size of the whole home on the floor plane.
    public static func footprint(rooms: [RoomScan]) -> (width: Double, depth: Double) {
        let pts = rooms.flatMap(\.walls).flatMap { [$0.start, $0.end] }
        guard let x0 = pts.map(\.x).min(), let x1 = pts.map(\.x).max(),
              let z0 = pts.map(\.z).min(), let z1 = pts.map(\.z).max() else { return (0, 0) }
        return (x1 - x0, z1 - z0)
    }
}
