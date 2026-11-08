import XCTest
@testable import MekanCore

final class ScanQualityTests: XCTestCase {
    func testQualityCountsLowConfidenceSurfaces() {
        var scan = roomFromCorners(rect4x3)
        scan.walls[0].confidence = .low
        scan.walls[1].confidence = .medium
        scan.walls[2].confidence = .high
        // walls[3] has no confidence (old scan) -> ignored
        let q = ScanQuality(scan: scan)
        XCTAssertEqual(q.lowConfidenceWallIDs, ["w0"])
        XCTAssertEqual(q.ratedWalls, 3)
        XCTAssertEqual(q.level, .medium)
    }

    func testAllHighIsGood() {
        var scan = roomFromCorners(rect4x3)
        for i in scan.walls.indices { scan.walls[i].confidence = .high }
        XCTAssertEqual(ScanQuality(scan: scan).level, .high)
    }

    func testManyLowWallsIsPoor() {
        var scan = roomFromCorners(rect4x3)
        for i in scan.walls.indices { scan.walls[i].confidence = i < 2 ? .low : .high }
        XCTAssertEqual(ScanQuality(scan: scan).level, .low)
    }

    func testOldScanWithoutConfidenceIsUnknown() {
        XCTAssertNil(ScanQuality(scan: roomFromCorners(rect4x3)).level)
    }

    func testConfidenceIsOptionalInJSON() throws {
        var scan = roomFromCorners(rect4x3)
        scan.walls[0].confidence = .low
        let back = try RoomScan.decoder.decode(RoomScan.self, from: RoomScan.encoder.encode(scan))
        XCTAssertEqual(back.walls[0].confidence, .low)
        XCTAssertNil(back.walls[1].confidence)
    }
}

final class TurkishNamesTests: XCTestCase {
    func testAttributesRefineFurnitureNames() {
        XCTAssertEqual(FurnitureNames.turkish("sofa", attributes: ["SofaType.lShaped"]), "L koltuk")
        XCTAssertEqual(FurnitureNames.turkish("sofa", attributes: ["SofaType.singleSeat"]), "Berjer")
        XCTAssertEqual(FurnitureNames.turkish("table", attributes: ["TableType.coffee"]), "Sehpa")
        XCTAssertEqual(FurnitureNames.turkish("table", attributes: ["TableType.dining"]), "Yemek masası")
        XCTAssertEqual(FurnitureNames.turkish("chair", attributes: ["ChairType.dining"]), "Yemek sandalyesi")
        XCTAssertEqual(FurnitureNames.turkish("chair", attributes: ["ChairType.stool"]), "Tabure")
        XCTAssertEqual(FurnitureNames.turkish("storage", attributes: ["StorageType.shelf"]), "Raf")
        XCTAssertEqual(FurnitureNames.turkish("sofa", attributes: []), "Koltuk")
    }

    func testRoomTypeNames() {
        XCTAssertEqual(RoomTypeNames.turkish("livingRoom"), "Salon")
        XCTAssertEqual(RoomTypeNames.turkish("bedroom"), "Yatak odası")
        XCTAssertEqual(RoomTypeNames.turkish("kitchen"), "Mutfak")
        XCTAssertNil(RoomTypeNames.turkish("unidentified"))
        XCTAssertNil(RoomTypeNames.turkish(nil))
    }

    func testRoundTableGetsACircularTop() {
        let parts = FurnitureBlueprint.parts(category: "table", size: Point3(x: 1, y: 0.75, z: 1), backSign: 1,
                                             attributes: ["TableShapeType.circular"])
        let top = parts.max { $0.center.y < $1.center.y }!
        XCTAssertEqual(top.shape, .cylinder)
        XCTAssertEqual(top.size.x, 1, accuracy: 1e-9)
    }
}

final class PlanSVGTests: XCTestCase {
    private func svg() -> String {
        var scan = roomFromCorners(rect4x3)
        scan.openings = [Opening(id: "d", kind: .door, wallId: "w0", center: Point3(x: 1, y: 1, z: 0), width: 0.9, height: 2)]
        scan.objects = [RoomObject(id: "s", category: "sofa", center: Point3(x: 2, y: 0.4, z: 2),
                                   size: Point3(x: 2, y: 0.8, z: 0.9), yaw: 0)]
        return PlanSVG.make(scan: scan)
    }

    func testIsAStandaloneSVGDocumentInCentimeters() {
        let s = svg()
        XCTAssertTrue(s.hasPrefix("<?xml"))
        XCTAssertTrue(s.contains("<svg xmlns=\"http://www.w3.org/2000/svg\""))
        XCTAssertTrue(s.hasSuffix("</svg>\n"))
    }

    func testHasOneLinePerWallAndLengthLabels() {
        let s = svg()
        XCTAssertEqual(s.components(separatedBy: "class=\"wall\"").count - 1, 4)
        XCTAssertTrue(s.contains(">4.00 m<"))
        XCTAssertTrue(s.contains(">3.00 m<"))
    }

    func testIncludesDoorsAndLabeledFurniture() {
        let s = svg()
        XCTAssertTrue(s.contains("class=\"door\""))
        XCTAssertTrue(s.contains(">Koltuk<"))
    }

    func testEscapesUserText() {
        var scan = roomFromCorners(rect4x3)
        scan.name = "Salon <1> & \"2\""
        let s = PlanSVG.make(scan: scan)
        XCTAssertTrue(s.contains("Salon &lt;1&gt; &amp; &quot;2&quot;"))
        XCTAssertFalse(s.contains("<1>"))
    }
}
