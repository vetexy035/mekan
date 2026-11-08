import XCTest
@testable import MekanCore

/// 4 m × 3 m room, 2.7 m ceiling, floor at y = 0.
/// Door 0.9 × 2.0 on w0 (z = 0) at x = 1; window 1.2 × 1.2 on w2 (z = 3) at x = 2, sill at 0.9 m.
final class FitCheckTests: XCTestCase {
    private func room() -> RoomScan {
        var scan = roomFromCorners(rect4x3)
        scan.floorY = 0
        scan.openings = [
            Opening(id: "d", kind: .door, wallId: "w0", center: Point3(x: 1, y: 1, z: 0), width: 0.9, height: 2.0),
            Opening(id: "w", kind: .window, wallId: "w2", center: Point3(x: 2, y: 1.5, z: 3), width: 1.2, height: 1.2),
        ]
        return scan
    }

    private let sofa = FurnitureSize(width: 2.2, depth: 0.9, height: 0.8)

    func testCeilingHeight() {
        XCTAssertTrue(FitCheck.check(sofa, in: room()).fitsUnderCeiling)
        XCTAssertFalse(FitCheck.check(FurnitureSize(width: 1, depth: 0.6, height: 2.8), in: room()).fitsUnderCeiling)
    }

    func testSofaGoesStraightThroughTheDoor() {
        XCTAssertEqual(FitCheck.check(sofa, in: room()).door, .straight)
    }

    func testThinTallPanelOnlyPassesTilted() {
        // 2.05 m is taller than the 2.0 m door, but a 5 cm thick panel can go through at an angle.
        let panel = FurnitureSize(width: 2.2, depth: 0.05, height: 2.05)
        XCTAssertEqual(FitCheck.check(panel, in: room()).door, .tilted)
    }

    func testBulkyItemDoesNotPass() {
        let cube = FurnitureSize(width: 1.0, depth: 1.0, height: 2.0)
        XCTAssertEqual(FitCheck.check(cube, in: room()).door, .no)
    }

    func testNoDoorsMeansUnknown() {
        var scan = room()
        scan.openings.removeAll { $0.kind == .door }
        XCTAssertNil(FitCheck.check(sofa, in: scan).door)
    }

    func testFreeWallSpotsSkipTheDoorway() {
        let spots = FitCheck.check(sofa, in: room()).spots
        XCTAssertEqual(Set(spots.map(\.wallId)), ["w0", "w1", "w2", "w3"])
        let w0 = spots.first { $0.wallId == "w0" }!
        XCTAssertEqual(w0.freeLength, 2.45, accuracy: 1e-9) // 4 m minus door (0.9) and 10 cm each side, from 1.55 m
        XCTAssertEqual(w0.start.x, 1.55, accuracy: 1e-9)
        XCTAssertEqual(w0.end.x, 4, accuracy: 1e-9)
    }

    func testLowSofaCanGoUnderTheWindowButATallItemCannot() {
        XCTAssertTrue(FitCheck.check(sofa, in: room()).spots.contains { $0.wallId == "w2" })
        let cabinet = FurnitureSize(width: 2.2, depth: 0.5, height: 1.0)
        XCTAssertFalse(FitCheck.check(cabinet, in: room()).spots.contains { $0.wallId == "w2" })
    }

    func testExistingFurnitureAgainstAWallBlocksIt() {
        var scan = room()
        scan.objects = [RoomObject(id: "bed", category: "bed", center: Point3(x: 2, y: 0.3, z: 2.5),
                                   size: Point3(x: 1.6, y: 0.6, z: 2.0), yaw: 0)]
        let walls = Set(FitCheck.check(sofa, in: scan).spots.map(\.wallId))
        XCTAssertFalse(walls.contains("w2"))
        XCTAssertTrue(walls.contains("w1"))
    }

    func testWalkwayInFrontOfTheItem() {
        let deep = FurnitureSize(width: 1.0, depth: 2.6, height: 0.8)
        let spots = FitCheck.check(deep, in: room()).spots
        // 3 m deep across w0/w2 leaves only 40 cm; 4 m across w1/w3 leaves 1.4 m.
        XCTAssertFalse(spots.first { $0.wallId == "w0" }!.leavesWalkway)
        XCTAssertTrue(spots.first { $0.wallId == "w1" }!.leavesWalkway)
    }

    func testTooWideForEveryWall() {
        XCTAssertTrue(FitCheck.check(FurnitureSize(width: 4.5, depth: 0.5, height: 0.8), in: room()).spots.isEmpty)
    }
}
