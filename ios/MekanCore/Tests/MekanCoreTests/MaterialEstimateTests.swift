import XCTest
@testable import MekanCore

/// 4 m × 3 m room, 2.7 m walls, one 0.9 × 2.0 door and one 1.2 × 1.2 window.
final class MaterialEstimateTests: XCTestCase {
    private func room() -> RoomScan {
        var scan = roomFromCorners(rect4x3)
        scan.openings = [
            Opening(id: "d", kind: .door, wallId: "w0", center: Point3(x: 1, y: 1, z: 0), width: 0.9, height: 2.0),
            Opening(id: "w", kind: .window, wallId: "w2", center: Point3(x: 2, y: 1.5, z: 3), width: 1.2, height: 1.2),
        ]
        return scan
    }

    func testNetWallAreaSubtractsDoorsAndWindows() {
        let e = MaterialEstimate(scan: room())
        XCTAssertEqual(e.grossWallArea, 37.8, accuracy: 1e-9)
        XCTAssertEqual(e.netWallArea, 34.56, accuracy: 1e-9)
    }

    func testPaintLitersUseCoatsAndCoverage() {
        let e = MaterialEstimate(scan: room(), settings: .init(paintCoats: 2, paintCoverage: 10))
        XCTAssertEqual(e.paintLiters, 6.912, accuracy: 1e-9)
    }

    func testPaintCansPickTheLeastPaintThenFewestCans() {
        XCTAssertEqual(MaterialEstimate.cans(for: 6.9), [7.5: 1])
        XCTAssertEqual(MaterialEstimate.cans(for: 24), [15: 1, 7.5: 1, 2.5: 1])
        XCTAssertEqual(MaterialEstimate.cans(for: 2.0), [2.5: 1])
        XCTAssertEqual(MaterialEstimate.cans(for: 0), [:])
    }

    func testFloorAreaIncludesWaste() {
        let e = MaterialEstimate(scan: room(), settings: .init(floorWaste: 0.10))
        XCTAssertEqual(e.floorAreaWithWaste, 13.2, accuracy: 1e-9)
    }

    func testSkirtingSkipsDoorwaysAndComesIn240cmPieces() {
        let e = MaterialEstimate(scan: room())
        XCTAssertEqual(e.skirtingMeters, 13.1, accuracy: 1e-9)
        XCTAssertEqual(e.skirtingPieces, 6)
    }

    func testWallpaperRollsByStrips() {
        // 13.1 m to cover / 0.53 m strips = 25 strips; a 10.05 m roll gives 3 strips of 2.8 m.
        XCTAssertEqual(MaterialEstimate(scan: room()).wallpaperRolls, 9)
    }

    func testCurtainFabricIsTwiceTheWindowWidth() {
        XCTAssertEqual(MaterialEstimate(scan: room()).curtainFabricMeters, 2.4, accuracy: 1e-9)
    }

    func testCostUsesWhatYouActuallyBuy() {
        let prices = MaterialPrices(paintPerLiter: 300, floorPerSquareMeter: 500, skirtingPerPiece: 120,
                                    wallpaperPerRoll: 0, curtainPerMeter: 0)
        let e = MaterialEstimate(scan: room())
        // 7.5 L bought (not 6.9), 13.2 m² floor, 6 skirting pieces.
        XCTAssertEqual(e.cost(prices).paint, 2250, accuracy: 1e-9)
        XCTAssertEqual(e.cost(prices).floor, 6600, accuracy: 1e-9)
        XCTAssertEqual(e.cost(prices).skirting, 720, accuracy: 1e-9)
        XCTAssertEqual(e.cost(prices).total, 9570, accuracy: 1e-9)
    }

    func testEmptyScanNeedsNothing() {
        let e = MaterialEstimate(scan: RoomScan(name: "Boş"))
        XCTAssertEqual(e.paintLiters, 0)
        XCTAssertEqual(e.wallpaperRolls, 0)
        XCTAssertEqual(e.skirtingPieces, 0)
    }
}
