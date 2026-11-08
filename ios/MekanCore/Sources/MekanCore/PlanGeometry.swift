import Foundation

/// Pure geometry helpers for drawing the top-down plan (meters, XZ plane).
public enum PlanGeometry {
    /// Average of all wall endpoints — good enough as "inside the room" reference.
    public static func centroid(of walls: [Wall]) -> Point2 {
        let pts = walls.flatMap { [$0.start, $0.end] }
        guard !pts.isEmpty else { return Point2(x: 0, z: 0) }
        let n = Double(pts.count)
        return Point2(x: pts.reduce(0) { $0 + $1.x } / n, z: pts.reduce(0) { $0 + $1.z } / n)
    }

    /// Wall midpoint pushed `offset` meters along the wall normal, on the side away
    /// from the room center, so length labels don't cover the interior.
    public static func labelAnchor(for wall: Wall, roomCenter: Point2, offset: Double) -> Point2 {
        let mid = Point2(x: (wall.start.x + wall.end.x) / 2, z: (wall.start.z + wall.end.z) / 2)
        let len = wall.length
        guard len > 0 else { return mid }
        var nx = -(wall.end.z - wall.start.z) / len
        var nz = (wall.end.x - wall.start.x) / len
        // Flip the normal if it points toward the room center.
        if nx * (roomCenter.x - mid.x) + nz * (roomCenter.z - mid.z) > 0 { nx = -nx; nz = -nz }
        return Point2(x: mid.x + nx * offset, z: mid.z + nz * offset)
    }

    public static func lengthLabel(_ meters: Double) -> String {
        String(format: "%.2f m", meters)
    }
}

/// Turkish display names for RoomPlan object categories.
public enum FurnitureNames {
    private static let names: [String: String] = [
        "storage": "Dolap", "refrigerator": "Buzdolabı", "stove": "Ocak", "bed": "Yatak",
        "sink": "Lavabo", "washerDryer": "Çamaşır makinesi", "toilet": "Klozet",
        "bathtub": "Küvet", "oven": "Fırın", "dishwasher": "Bulaşık makinesi",
        "table": "Masa", "sofa": "Koltuk", "chair": "Sandalye", "fireplace": "Şömine",
        "television": "Televizyon", "stairs": "Merdiven",
    ]

    /// RoomPlan iOS 17 attributes ("Type.value") that change the everyday name.
    private static let refined: [String: String] = [
        "sofa|SofaType.lShaped": "L koltuk", "sofa|SofaType.singleSeat": "Berjer",
        "table|TableType.coffee": "Sehpa", "table|TableType.dining": "Yemek masası",
        "chair|ChairType.dining": "Yemek sandalyesi", "chair|ChairType.stool": "Tabure",
        "chair|ChairType.swivel": "Döner sandalye", "chair|ChairType.lounge": "Dinlenme koltuğu",
        "storage|StorageType.shelf": "Raf", "storage|StorageType.cabinet": "Dolap",
    ]

    public static func turkish(_ category: String, attributes: [String] = []) -> String {
        for a in attributes { if let n = refined["\(category)|\(a)"] { return n } }
        return names[category] ?? category
    }
}

/// Turkish names for RoomPlan room types (iOS 17 sections).
public enum RoomTypeNames {
    private static let names: [String: String] = [
        "livingRoom": "Salon", "bedroom": "Yatak odası", "kitchen": "Mutfak",
        "bathroom": "Banyo", "diningRoom": "Yemek odası",
    ]
    public static func turkish(_ type: String?) -> String? { type.flatMap { names[$0] } }
}
