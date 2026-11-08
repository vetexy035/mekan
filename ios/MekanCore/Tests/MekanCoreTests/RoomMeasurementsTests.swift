import XCTest
@testable import MekanCore

final class RoomMeasurementsTests: XCTestCase {
    func testRectangleRoomDimensions() {
        let m = RoomMeasurements(scan: roomFromCorners(rect4x3))
        XCTAssertEqual(m.length, 4, accuracy: 1e-6)
        XCTAssertEqual(m.width, 3, accuracy: 1e-6)
        XCTAssertEqual(m.ceilingHeight, 2.7, accuracy: 1e-6)
        XCTAssertEqual(m.perimeter, 14, accuracy: 1e-6)
    }

    func testRectangleRoomAreaIsExactFromClosedPolygon() {
        let m = RoomMeasurements(scan: roomFromCorners(rect4x3))
        XCTAssertEqual(m.floorArea, 12, accuracy: 1e-6)
        XCTAssertFalse(m.isAreaEstimated)
    }

    func testRotatedRoomGivesSameDimensions() {
        let m = RoomMeasurements(scan: roomFromCorners(rotated(rect4x3, degrees: 30)))
        XCTAssertEqual(m.length, 4, accuracy: 1e-6)
        XCTAssertEqual(m.width, 3, accuracy: 1e-6)
        XCTAssertEqual(m.floorArea, 12, accuracy: 1e-6)
    }

    func testLShapedRoomArea() {
        // 5x4 rectangle with a 2x2 corner cut out -> 20 - 4 = 16
        let l: [(Double, Double)] = [(0, 0), (5, 0), (5, 2), (3, 2), (3, 4), (0, 4)]
        let m = RoomMeasurements(scan: roomFromCorners(l))
        XCTAssertEqual(m.floorArea, 16, accuracy: 1e-6)
        XCTAssertEqual(m.length, 5, accuracy: 1e-6)
        XCTAssertEqual(m.width, 4, accuracy: 1e-6)
    }

    func testWallsInRandomOrderAndDirectionStillChain() {
        var scan = roomFromCorners(rect4x3)
        // Shuffle deterministically and flip one wall's direction, small gaps like real scans.
        var w = scan.walls
        w.swapAt(0, 2)
        let flipped = w[1]
        w[1] = Wall(id: flipped.id,
                    start: Point2(x: flipped.end.x + 0.05, z: flipped.end.z),
                    end: flipped.start, height: flipped.height)
        scan.walls = w
        let m = RoomMeasurements(scan: scan)
        XCTAssertFalse(m.isAreaEstimated)
        XCTAssertEqual(m.floorArea, 12, accuracy: 0.2)
    }

    func testOpenRoomFallsBackToBoundingBoxArea() {
        var scan = roomFromCorners(rect4x3)
        scan.walls.removeLast() // missing wall -> polygon cannot close
        let m = RoomMeasurements(scan: scan)
        XCTAssertTrue(m.isAreaEstimated)
        XCTAssertEqual(m.floorArea, 12, accuracy: 1e-6)
    }

    func testEmptyScanIsAllZero() {
        let m = RoomMeasurements(scan: RoomScan(name: "Boş"))
        XCTAssertEqual(m.floorArea, 0)
        XCTAssertEqual(m.width, 0)
        XCTAssertEqual(m.length, 0)
        XCTAssertEqual(m.ceilingHeight, 0)
    }

    func testCountsOpeningsByKindAndObjects() {
        var scan = roomFromCorners(rect4x3)
        scan.openings = [
            Opening(id: "d", kind: .door, wallId: "w0", center: Point3(x: 1, y: 1, z: 0), width: 0.9, height: 2),
            Opening(id: "a", kind: .window, wallId: "w1", center: Point3(x: 4, y: 1.5, z: 1), width: 1.2, height: 1.2),
            Opening(id: "b", kind: .window, wallId: "w2", center: Point3(x: 2, y: 1.5, z: 3), width: 1.2, height: 1.2),
        ]
        scan.objects = [RoomObject(id: "s", category: "sofa", center: Point3(x: 2, y: 0.4, z: 1),
                                   size: Point3(x: 2, y: 0.8, z: 0.9), yaw: 0)]
        let m = RoomMeasurements(scan: scan)
        XCTAssertEqual(m.doorCount, 1)
        XCTAssertEqual(m.windowCount, 2)
        XCTAssertEqual(m.objectCount, 1)
    }
}
