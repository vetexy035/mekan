import Foundation

/// A point on the floor plane (meters). RoomPlan's Y axis is up, so the floor is XZ.
public struct Point2: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var z: Double
    public init(x: Double, z: Double) { self.x = x; self.z = z }

    public func distance(to o: Point2) -> Double { hypot(x - o.x, z - o.z) }
}

public struct Point3: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
}

public struct Wall: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var start: Point2
    public var end: Point2
    public var height: Double
    public init(id: String, start: Point2, end: Point2, height: Double) {
        self.id = id; self.start = start; self.end = end; self.height = height
    }

    public var length: Double { start.distance(to: end) }
}

public enum OpeningKind: String, Codable, Sendable {
    case door, window, opening
}

public struct Opening: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: OpeningKind
    public var wallId: String?
    public var center: Point3
    public var width: Double
    public var height: Double
    public init(id: String, kind: OpeningKind, wallId: String?, center: Point3, width: Double, height: Double) {
        self.id = id; self.kind = kind; self.wallId = wallId
        self.center = center; self.width = width; self.height = height
    }
}

public struct RoomObject: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    /// RoomPlan category name, e.g. "sofa", "table", "bed".
    public var category: String
    public var center: Point3
    /// Width (x), height (y), depth (z) in the object's local frame.
    public var size: Point3
    /// Rotation around the vertical axis, radians.
    public var yaw: Double
    public init(id: String, category: String, center: Point3, size: Point3, yaw: Double) {
        self.id = id; self.category = category; self.center = center; self.size = size; self.yaw = yaw
    }
}

/// Our own stable scan format (v1). RoomPlan's Codable output is version-dependent,
/// so the app converts CapturedRoom into this before saving.
public struct RoomScan: Codable, Equatable, Identifiable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var id: UUID
    public var name: String
    public var capturedAt: Date
    public var walls: [Wall]
    public var openings: [Opening]
    public var objects: [RoomObject]

    public init(id: UUID = UUID(), name: String, capturedAt: Date = Date(),
                walls: [Wall] = [], openings: [Opening] = [], objects: [RoomObject] = []) {
        self.version = Self.currentVersion
        self.id = id
        self.name = name
        // Whole seconds so the ISO-8601 round trip is lossless.
        self.capturedAt = Date(timeIntervalSince1970: floor(capturedAt.timeIntervalSince1970))
        self.walls = walls
        self.openings = openings
        self.objects = objects
    }

    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
