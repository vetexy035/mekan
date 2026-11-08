import Foundation

public struct WallColor: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var name: String
    /// "#RRGGBB"
    public var hex: String
    public var id: String { hex }

    public init(name: String, hex: String) { self.name = name; self.hex = hex }

    /// 0…1 components; invalid hex falls back to white.
    public var rgb: (r: Double, g: Double, b: Double) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return (1, 1, 1) }
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }
}

public enum FloorType: String, Codable, CaseIterable, Identifiable, Sendable {
    case oakParquet, walnutParquet, whiteOakParquet, greyTile, marble, carpet
    public var id: String { rawValue }

    public var turkishName: String {
        switch self {
        case .oakParquet: "Meşe parke"
        case .walnutParquet: "Ceviz parke"
        case .whiteOakParquet: "Açık meşe parke"
        case .greyTile: "Gri seramik"
        case .marble: "Mermer"
        case .carpet: "Halıfleks"
        }
    }

    /// Typical cutting waste when ordering this floor.
    public var typicalWaste: Double {
        switch self {
        case .oakParquet, .walnutParquet, .whiteOakParquet: 0.08
        case .greyTile, .marble: 0.10
        case .carpet: 0.05
        }
    }
}

/// The look chosen for a scanned room; saved next to the scan.
public struct ScanDesign: Codable, Equatable, Sendable {
    public var wallColor: WallColor
    public var floor: FloorType
    public init(wallColor: WallColor = DesignPalette.walls[0], floor: FloorType = .oakParquet) {
        self.wallColor = wallColor; self.floor = floor
    }
}

public enum DesignPalette {
    /// Popular interior wall colors (names in Turkish, as paint shops call them).
    public static let walls: [WallColor] = [
        WallColor(name: "Kırık beyaz", hex: "#F3F0E8"),
        WallColor(name: "Saf beyaz", hex: "#FAFAFA"),
        WallColor(name: "Bej", hex: "#E6D9C3"),
        WallColor(name: "Açık gri", hex: "#D9D9D6"),
        WallColor(name: "Antrasit", hex: "#4A4D52"),
        WallColor(name: "Adaçayı yeşili", hex: "#B7C4A8"),
        WallColor(name: "Toz mavi", hex: "#AFC3D2"),
        WallColor(name: "Gül kurusu", hex: "#D8B4AE"),
        WallColor(name: "Hardal", hex: "#D6A84A"),
        WallColor(name: "Gece mavisi", hex: "#2E3F57"),
    ]
}
