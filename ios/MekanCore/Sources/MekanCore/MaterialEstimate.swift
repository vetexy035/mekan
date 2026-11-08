import Foundation

/// User prices in TL per purchase unit.
public struct MaterialPrices: Codable, Equatable, Sendable {
    public var paintPerLiter: Double
    public var floorPerSquareMeter: Double
    public var skirtingPerPiece: Double
    public var wallpaperPerRoll: Double
    public var curtainPerMeter: Double

    public init(paintPerLiter: Double = 0, floorPerSquareMeter: Double = 0, skirtingPerPiece: Double = 0,
                wallpaperPerRoll: Double = 0, curtainPerMeter: Double = 0) {
        self.paintPerLiter = paintPerLiter
        self.floorPerSquareMeter = floorPerSquareMeter
        self.skirtingPerPiece = skirtingPerPiece
        self.wallpaperPerRoll = wallpaperPerRoll
        self.curtainPerMeter = curtainPerMeter
    }
}

public struct MaterialCost: Equatable, Sendable {
    public let paint, floor, skirting, wallpaper, curtain: Double
    public var total: Double { paint + floor + skirting + wallpaper + curtain }
}

/// Quantities to buy for repainting, re-flooring, skirting, wallpaper and curtains,
/// derived from the scanned walls and openings.
public struct MaterialEstimate: Equatable, Sendable {
    public struct Settings: Equatable, Sendable {
        public var paintCoats: Double
        /// m² one liter covers per coat (typical interior emulsion: ~10).
        public var paintCoverage: Double
        /// Extra flooring for cuts, e.g. 0.10 = 10 %.
        public var floorWaste: Double
        public init(paintCoats: Double = 2, paintCoverage: Double = 10, floorWaste: Double = 0.10) {
            self.paintCoats = paintCoats; self.paintCoverage = paintCoverage; self.floorWaste = floorWaste
        }
    }

    public static let canSizes: [Double] = [15, 7.5, 2.5]
    public static let skirtingPieceLength = 2.4
    public static let wallpaperRollWidth = 0.53
    public static let wallpaperRollLength = 10.05
    /// Curtain fabric is usually twice the window width for pleats.
    public static let curtainFullness = 2.0

    public let grossWallArea: Double
    public let netWallArea: Double
    public let paintLiters: Double
    /// Can size (L) → count.
    public let paintCans: [Double: Int]
    public let floorAreaWithWaste: Double
    public let skirtingMeters: Double
    public let skirtingPieces: Int
    public let wallpaperRolls: Int
    public let curtainFabricMeters: Double

    public init(scan: RoomScan, settings: Settings = Settings()) {
        let m = RoomMeasurements(scan: scan)
        grossWallArea = scan.walls.reduce(0) { $0 + $1.length * $1.height }
        let openingArea = scan.openings.reduce(0) { $0 + $1.width * $1.height }
        netWallArea = max(0, grossWallArea - openingArea)

        paintLiters = settings.paintCoverage > 0 ? netWallArea * settings.paintCoats / settings.paintCoverage : 0
        paintCans = Self.cans(for: paintLiters)

        floorAreaWithWaste = m.floorArea * (1 + settings.floorWaste)

        // Skirting and wallpaper run along the walls but not across doorways.
        let doorways = scan.openings.filter { $0.kind != .window }.reduce(0) { $0 + $1.width }
        skirtingMeters = max(0, m.perimeter - doorways)
        skirtingPieces = Int(ceilSafe(skirtingMeters / Self.skirtingPieceLength))

        let strips = ceilSafe(skirtingMeters / Self.wallpaperRollWidth)
        let stripsPerRoll = max(1, floor(Self.wallpaperRollLength / (m.ceilingHeight + 0.1)))
        wallpaperRolls = Int(ceilSafe(strips / stripsPerRoll))

        curtainFabricMeters = scan.openings.filter { $0.kind == .window }
            .reduce(0) { $0 + $1.width * Self.curtainFullness }
    }

    /// Liters actually bought (sum of the chosen cans).
    public var paintLitersToBuy: Double { paintCans.reduce(0) { $0 + $1.key * Double($1.value) } }

    public func cost(_ p: MaterialPrices) -> MaterialCost {
        MaterialCost(paint: paintLitersToBuy * p.paintPerLiter,
                     floor: floorAreaWithWaste * p.floorPerSquareMeter,
                     skirting: Double(skirtingPieces) * p.skirtingPerPiece,
                     wallpaper: Double(wallpaperRolls) * p.wallpaperPerRoll,
                     curtain: curtainFabricMeters * p.curtainPerMeter)
    }

    /// Cheapest set of 15 / 7.5 / 2.5 L cans: least paint left over, then fewest cans.
    public static func cans(for liters: Double) -> [Double: Int] {
        guard liters > 1e-9 else { return [:] }
        let (big, mid, small) = (canSizes[0], canSizes[1], canSizes[2])
        var best: (total: Double, count: Int, combo: [Double: Int])?
        for nBig in 0...Int(ceilSafe(liters / big)) {
            for nMid in 0...Int(ceilSafe(liters / mid)) {
                let rest = liters - Double(nBig) * big - Double(nMid) * mid
                let nSmall = max(0, Int(ceilSafe(rest / small)))
                let total = Double(nBig) * big + Double(nMid) * mid + Double(nSmall) * small
                let count = nBig + nMid + nSmall
                if best == nil || total < best!.total - 1e-9 || (abs(total - best!.total) < 1e-9 && count < best!.count) {
                    var combo: [Double: Int] = [:]
                    if nBig > 0 { combo[big] = nBig }
                    if nMid > 0 { combo[mid] = nMid }
                    if nSmall > 0 { combo[small] = nSmall }
                    best = (total, count, combo)
                }
            }
        }
        return best?.combo ?? [:]
    }
}

/// ceil that ignores floating-point dust (5.0000000001 → 5, not 6).
private func ceilSafe(_ v: Double) -> Double { ceil(v - 1e-9) }
