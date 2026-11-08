import XCTest
@testable import MekanCore

final class ScanDesignTests: XCTestCase {
    func testDefaultIsWarmWhiteWallsAndOakParquet() {
        let d = ScanDesign()
        XCTAssertEqual(d.wallColor, DesignPalette.walls[0])
        XCTAssertEqual(d.floor, .oakParquet)
    }

    func testRoundTripsThroughJSON() throws {
        let d = ScanDesign(wallColor: DesignPalette.walls[3], floor: .greyTile)
        let back = try JSONDecoder().decode(ScanDesign.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(back, d)
    }

    func testHexParsing() {
        let c = WallColor(name: "Test", hex: "#3A7BD5")
        XCTAssertEqual(c.rgb.r, 0x3A / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.rgb.g, 0x7B / 255.0, accuracy: 1e-9)
        XCTAssertEqual(c.rgb.b, 0xD5 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(WallColor(name: "x", hex: "zz").rgb.r, 1) // invalid -> white
    }

    func testPaletteHasDistinctNamedColors() {
        XCTAssertGreaterThanOrEqual(DesignPalette.walls.count, 8)
        XCTAssertEqual(Set(DesignPalette.walls.map(\.hex)).count, DesignPalette.walls.count)
        XCTAssertTrue(DesignPalette.walls.allSatisfy { !$0.name.isEmpty })
    }

    func testFloorTypesKnowTheirWasteAndName() {
        XCTAssertEqual(FloorType.oakParquet.turkishName, "Meşe parke")
        XCTAssertEqual(FloorType.greyTile.typicalWaste, 0.10, accuracy: 1e-9)
        XCTAssertEqual(FloorType.carpet.typicalWaste, 0.05, accuracy: 1e-9)
    }
}
