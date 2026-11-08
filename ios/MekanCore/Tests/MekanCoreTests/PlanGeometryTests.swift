import XCTest
@testable import MekanCore

final class PlanGeometryTests: XCTestCase {
    func testCentroidOfRectangleCorners() {
        let c = PlanGeometry.centroid(of: roomFromCorners(rect4x3).walls)
        XCTAssertEqual(c.x, 2, accuracy: 1e-6)
        XCTAssertEqual(c.z, 1.5, accuracy: 1e-6)
    }

    func testLabelSitsOutsideTheRoomAtWallMidpoint() {
        let scan = roomFromCorners(rect4x3)
        let center = PlanGeometry.centroid(of: scan.walls)
        // w0 runs (0,0)->(4,0); the room is on +z, so the label goes to -z.
        let p = PlanGeometry.labelAnchor(for: scan.walls[0], roomCenter: center, offset: 0.3)
        XCTAssertEqual(p.x, 2, accuracy: 1e-6)
        XCTAssertEqual(p.z, -0.3, accuracy: 1e-6)
        // w1 runs (4,0)->(4,3); outside is +x.
        let q = PlanGeometry.labelAnchor(for: scan.walls[1], roomCenter: center, offset: 0.3)
        XCTAssertEqual(q.x, 4.3, accuracy: 1e-6)
        XCTAssertEqual(q.z, 1.5, accuracy: 1e-6)
    }

    func testLengthLabelFormatsMetersWithTwoDecimals() {
        XCTAssertEqual(PlanGeometry.lengthLabel(4), "4.00 m")
        XCTAssertEqual(PlanGeometry.lengthLabel(2.346), "2.35 m") // 2.345 is 2.34499… in binary
    }

    func testTurkishCategoryNames() {
        XCTAssertEqual(FurnitureNames.turkish("sofa"), "Koltuk")
        XCTAssertEqual(FurnitureNames.turkish("bed"), "Yatak")
        XCTAssertEqual(FurnitureNames.turkish("somethingNew"), "somethingNew")
    }
}
