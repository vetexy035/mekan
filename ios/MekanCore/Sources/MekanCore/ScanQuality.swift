import Foundation

/// How much to trust the scan, from RoomPlan's per-wall confidence.
public struct ScanQuality: Equatable, Sendable {
    /// Walls that carry a confidence value (older scans have none).
    public let ratedWalls: Int
    public let lowConfidenceWallIDs: [String]
    /// nil when no wall is rated (scan saved before confidence was recorded).
    public let level: Confidence?

    public init(scan: RoomScan) {
        let rated = scan.walls.filter { $0.confidence != nil }
        ratedWalls = rated.count
        lowConfidenceWallIDs = rated.filter { $0.confidence == .low }.map(\.id)
        guard !rated.isEmpty else { level = nil; return }
        let lowShare = Double(lowConfidenceWallIDs.count) / Double(rated.count)
        if lowShare >= 0.5 {
            level = .low
        } else if lowShare == 0 && rated.allSatisfy({ $0.confidence == .high }) {
            level = .high
        } else {
            level = .medium
        }
    }

    public var turkishSummary: String {
        switch level {
        case .high: "Tarama güvenilir. Ölçüler genelde ±2–5 cm içinde."
        case .medium: "Tarama çoğunlukla iyi; turuncu çizilen duvarları metreyle kontrol et."
        case .low: "Tarama zayıf. Işığı açıp yavaşça yeniden taramanı öneririz."
        case nil: "Bu tarama eski sürümle yapıldı; güven bilgisi yok."
        }
    }
}
