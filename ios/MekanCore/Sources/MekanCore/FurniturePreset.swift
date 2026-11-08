import Foundation

/// A piece of furniture to preview in AR: a RoomPlan category (drives the 3D shape)
/// plus real outer dimensions.
public struct FurniturePreset: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let category: String
    public let size: FurnitureSize
    public var attributes: [String] = []

    /// Width → x, height → y, depth → z (FurnitureBlueprint's local frame).
    public var blueprintSize: Point3 { Point3(x: size.width, y: size.height, z: size.depth) }

    public static func custom(category: String, size: FurnitureSize) -> FurniturePreset {
        func cm(_ m: Double) -> Int { Int((m * 100).rounded()) }
        return FurniturePreset(
            name: "\(FurnitureNames.turkish(category)) · \(cm(size.width)) × \(cm(size.depth)) × \(cm(size.height)) cm",
            category: category, size: size)
    }

    /// Common sizes in Turkish furniture stores (W × D × H).
    public static let all: [FurniturePreset] = [
        FurniturePreset(name: "Üçlü koltuk", category: "sofa", size: .init(width: 2.2, depth: 0.95, height: 0.85)),
        FurniturePreset(name: "İkili koltuk", category: "sofa", size: .init(width: 1.6, depth: 0.9, height: 0.85)),
        FurniturePreset(name: "Berjer", category: "sofa", size: .init(width: 0.8, depth: 0.85, height: 0.95),
                        attributes: ["SofaType.singleSeat"]),
        FurniturePreset(name: "Yemek masası (6 kişilik)", category: "table", size: .init(width: 1.6, depth: 0.9, height: 0.76),
                        attributes: ["TableType.dining"]),
        FurniturePreset(name: "Yuvarlak masa", category: "table", size: .init(width: 1.0, depth: 1.0, height: 0.76),
                        attributes: ["TableShapeType.circular"]),
        FurniturePreset(name: "Orta sehpa", category: "table", size: .init(width: 1.0, depth: 0.6, height: 0.45),
                        attributes: ["TableType.coffee"]),
        FurniturePreset(name: "Sandalye", category: "chair", size: .init(width: 0.45, depth: 0.5, height: 0.9)),
        FurniturePreset(name: "Çift kişilik yatak", category: "bed", size: .init(width: 1.6, depth: 2.05, height: 1.0)),
        FurniturePreset(name: "Tek kişilik yatak", category: "bed", size: .init(width: 0.9, depth: 2.0, height: 0.9)),
        FurniturePreset(name: "Gardırop", category: "storage", size: .init(width: 1.2, depth: 0.6, height: 2.1)),
        FurniturePreset(name: "TV ünitesi", category: "storage", size: .init(width: 1.8, depth: 0.45, height: 0.5)),
        FurniturePreset(name: "Kitaplık", category: "storage", size: .init(width: 0.8, depth: 0.35, height: 1.9),
                        attributes: ["StorageType.shelf"]),
        FurniturePreset(name: "Buzdolabı", category: "refrigerator", size: .init(width: 0.7, depth: 0.7, height: 1.85)),
    ]
}
