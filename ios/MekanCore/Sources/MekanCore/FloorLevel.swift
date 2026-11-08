import Foundation

extension RoomScan {
    /// Best guess of the floor height in RoomPlan's world frame:
    /// stored value → median door bottom (doors reach the floor) → lowest furniture bottom → 0.
    public var estimatedFloorY: Double {
        if let floorY { return floorY }
        let doorBottoms = openings.filter { $0.kind == .door }.map { $0.center.y - $0.height / 2 }
        if let median = FloorLevel.median(doorBottoms) { return median }
        if let lowest = objects.map({ $0.center.y - $0.size.y / 2 }).min() { return lowest }
        return 0
    }
}

/// Converts RoomPlan heights to heights above the floor.
public enum FloorLevel {
    /// Furniture whose bottom is within this distance of the floor (or below it) is
    /// treated as standing on the floor. Higher items (wall TV, shelves) keep their height.
    public static let snapDistance = 0.3

    /// Height above the floor of the object's center, snapping floor-standing items onto it.
    public static func restingCenterHeight(of o: RoomObject, floorY: Double) -> Double {
        let bottom = o.center.y - o.size.y / 2 - floorY
        return bottom < snapDistance ? o.size.y / 2 : o.center.y - floorY
    }

    /// Height above the floor of an opening's center. Doors and passages stand on the floor.
    public static func centerHeight(of o: Opening, floorY: Double) -> Double {
        o.kind == .window ? o.center.y - floorY : o.height / 2
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let mid = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }
}
