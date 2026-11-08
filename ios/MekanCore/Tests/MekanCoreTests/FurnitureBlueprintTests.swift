import XCTest
@testable import MekanCore

final class FurnitureBlueprintTests: XCTestCase {
    private let categories = ["table", "chair", "sofa", "bed", "storage", "refrigerator", "stove", "oven",
                              "dishwasher", "washerDryer", "sink", "toilet", "bathtub", "fireplace",
                              "television", "stairs", "somethingUnknown"]

    func testEveryPartStaysInsideTheDetectedBox() {
        let size = Point3(x: 1.6, y: 0.9, z: 0.8)
        for category in categories {
            for back in [1.0, -1.0] {
                let parts = FurnitureBlueprint.parts(category: category, size: size, backSign: back)
                XCTAssertFalse(parts.isEmpty, category)
                for p in parts {
                    let e = p.extent
                    XCTAssertLessThanOrEqual(abs(p.center.x) + e.x / 2, size.x / 2 + 1e-6, "\(category) x")
                    XCTAssertLessThanOrEqual(abs(p.center.y) + e.y / 2, size.y / 2 + 1e-6, "\(category) y")
                    XCTAssertLessThanOrEqual(abs(p.center.z) + e.z / 2, size.z / 2 + 1e-6, "\(category) z")
                }
            }
        }
    }

    func testTableHasTopAndFourLegs() {
        let parts = FurnitureBlueprint.parts(category: "table", size: Point3(x: 1.2, y: 0.75, z: 0.8), backSign: 1)
        XCTAssertEqual(parts.filter { $0.shape == .cylinder }.count, 4)
        XCTAssertEqual(parts.filter { $0.shape == .box }.count, 1)
    }

    func testChairBackrestIsOnTheBackSide() {
        for back in [1.0, -1.0] {
            let parts = FurnitureBlueprint.parts(category: "chair", size: Point3(x: 0.5, y: 0.9, z: 0.5), backSign: back)
            let highest = parts.max { $0.center.y < $1.center.y }!
            XCTAssertEqual(highest.center.z.sign, back.sign == .minus ? .minus : .plus)
        }
    }

    func testSofaHasSeparateSeatCushionsAndLegs() {
        let parts = FurnitureBlueprint.parts(category: "sofa", size: Point3(x: 2.2, y: 0.85, z: 0.95), backSign: 1)
        XCTAssertEqual(parts.filter { $0.shape == .cylinder }.count, 4)
        // Wide sofa -> 3 seat cushions and 3 back cushions, all soft-cornered.
        let cushions = parts.filter { $0.material == .cushion }
        XCTAssertEqual(cushions.count, 6)
        XCTAssertTrue(cushions.allSatisfy { $0.rounding >= 0.3 })
    }

    func testNarrowSofaHasTwoSeatCushions() {
        let parts = FurnitureBlueprint.parts(category: "sofa", size: Point3(x: 1.4, y: 0.85, z: 0.9), backSign: 1)
        XCTAssertEqual(parts.filter { $0.material == .cushion }.count, 4)
    }

    func testBedHasLegsAndDuvet() {
        let parts = FurnitureBlueprint.parts(category: "bed", size: Point3(x: 1.6, y: 0.9, z: 2.1), backSign: 1)
        XCTAssertEqual(parts.filter { $0.shape == .cylinder }.count, 4)
        XCTAssertEqual(parts.filter { $0.material == .fabric }.count, 1) // duvet
    }

    func testStorageDoorsHaveMetalHandlesOnTheFront() {
        for back in [1.0, -1.0] {
            let parts = FurnitureBlueprint.parts(category: "storage", size: Point3(x: 1.0, y: 1.8, z: 0.5), backSign: back)
            let handles = parts.filter { $0.material == .metal }
            XCTAssertEqual(handles.count, 2)
            XCTAssertTrue(handles.allSatisfy { ($0.center.z > 0) == (back < 0) }) // front = opposite of back
        }
    }

    func testStairsHaveOneStepPerRiser() {
        let parts = FurnitureBlueprint.parts(category: "stairs", size: Point3(x: 1, y: 1.8, z: 3), backSign: 1)
        XCTAssertEqual(parts.count, 10) // 1.8 m / 0.18 m risers
    }

    func testUnknownCategoryIsSingleBox() {
        let parts = FurnitureBlueprint.parts(category: "somethingUnknown", size: Point3(x: 1, y: 1, z: 1), backSign: 1)
        XCTAssertEqual(parts.count, 1)
    }
}

final class BackSideTests: XCTestCase {
    private let wall = Wall(id: "w", start: Point2(x: 0, z: 0), end: Point2(x: 4, z: 0), height: 2.7)

    private func sofa(yaw: Double) -> RoomObject {
        RoomObject(id: "s", category: "sofa", center: Point3(x: 2, y: 0.4, z: 0.6),
                   size: Point3(x: 2, y: 0.8, z: 0.9), yaw: yaw)
    }

    func testBackFacesNearestWall() {
        // yaw 0: local +z is world +z, wall is at -z -> back is -1
        XCTAssertEqual(FurnitureBlueprint.backSide(of: sofa(yaw: 0), walls: [wall], tables: []), -1)
        // yaw pi: local +z points to world -z, toward the wall -> back is +1
        XCTAssertEqual(FurnitureBlueprint.backSide(of: sofa(yaw: .pi), walls: [wall], tables: []), 1)
    }

    func testChairNearTableFacesTheTable() {
        let chair = RoomObject(id: "c", category: "chair", center: Point3(x: 2, y: 0.45, z: 0.6),
                               size: Point3(x: 0.5, y: 0.9, z: 0.5), yaw: 0)
        let table = RoomObject(id: "t", category: "table", center: Point3(x: 2, y: 0.4, z: 1.5),
                               size: Point3(x: 1.2, y: 0.75, z: 0.8), yaw: 0)
        // Table is at +z, so the back goes to -z even though... the wall is also at -z.
        XCTAssertEqual(FurnitureBlueprint.backSide(of: chair, walls: [wall], tables: [table]), -1)
        // Put the table on the wall side: the chair must turn its back away from it.
        let tableBehind = RoomObject(id: "t", category: "table", center: Point3(x: 2, y: 0.4, z: 0.1),
                                     size: table.size, yaw: 0)
        XCTAssertEqual(FurnitureBlueprint.backSide(of: chair, walls: [wall], tables: [tableBehind]), 1)
    }
}
