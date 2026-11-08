import XCTest
@testable import MekanCore

final class FurniturePresetTests: XCTestCase {
    func testPresetsCoverEverydayFurnitureWithTurkishNames() {
        let names = FurniturePreset.all.map(\.name)
        XCTAssertTrue(names.contains("Üçlü koltuk"))
        XCTAssertTrue(names.contains("Gardırop"))
        XCTAssertTrue(names.contains("Çift kişilik yatak"))
        XCTAssertGreaterThanOrEqual(FurniturePreset.all.count, 8)
    }

    func testPresetsUseKnownBlueprintCategories() {
        let known: Set<String> = ["sofa", "table", "chair", "bed", "storage", "television", "refrigerator"]
        XCTAssertTrue(FurniturePreset.all.allSatisfy { known.contains($0.category) })
    }

    func testPresetSizesAreRealisticMeters() {
        for p in FurniturePreset.all {
            XCTAssertTrue((0.3...3.0).contains(p.size.width), p.name)
            XCTAssertTrue((0.3...2.5).contains(p.size.depth), p.name)
            XCTAssertTrue((0.3...2.6).contains(p.size.height), p.name)
        }
    }

    func testCustomSizeKeepsTheChosenCategory() {
        let p = FurniturePreset.custom(category: "sofa", size: FurnitureSize(width: 1.8, depth: 0.9, height: 0.8))
        XCTAssertEqual(p.category, "sofa")
        XCTAssertEqual(p.name, "Koltuk · 180 × 90 × 80 cm")
    }

    func testSizeAsBlueprintPoint() {
        let p = FurniturePreset.custom(category: "table", size: FurnitureSize(width: 1.6, depth: 0.9, height: 0.75))
        XCTAssertEqual(p.blueprintSize, Point3(x: 1.6, y: 0.75, z: 0.9))
    }
}
