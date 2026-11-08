import XCTest
@testable import MekanCore

final class RoomEditingTests: XCTestCase {
    private func room() -> RoomScan {
        var scan = roomFromCorners(rect4x3)
        scan.openings = [Opening(id: "d", kind: .door, wallId: "w2", center: Point3(x: 3, y: 1, z: 3), width: 0.9, height: 2)]
        scan.objects = [RoomObject(id: "s", category: "sofa", center: Point3(x: 2, y: 0.4, z: 1),
                                   size: Point3(x: 2, y: 0.8, z: 0.9), yaw: 0)]
        return scan
    }

    func testSettingAWallLengthStretchesTheRoomAlongIt() {
        let edited = RoomEditing.setLength(of: "w0", to: 4.2, in: room())
        let m = RoomMeasurements(scan: edited)
        XCTAssertEqual(m.length, 4.2, accuracy: 1e-9)
        XCTAssertEqual(m.width, 3, accuracy: 1e-9)
        XCTAssertEqual(m.floorArea, 12.6, accuracy: 1e-9)
        // The opposite wall follows, so the room stays rectangular.
        XCTAssertEqual(edited.walls[2].length, 4.2, accuracy: 1e-9)
    }

    func testStretchMovesOpeningsAndFurnitureButKeepsTheirSize() {
        let edited = RoomEditing.setLength(of: "w0", to: 4.4, in: room())
        XCTAssertEqual(edited.openings[0].center.x, 3.3, accuracy: 1e-9)
        XCTAssertEqual(edited.openings[0].width, 0.9, accuracy: 1e-9)
        XCTAssertEqual(edited.objects[0].center.x, 2.2, accuracy: 1e-9)
        XCTAssertEqual(edited.objects[0].size.x, 2, accuracy: 1e-9)
    }

    func testStretchWorksOnRotatedRooms() {
        let scan = roomFromCorners(rotated(rect4x3, degrees: 30))
        let edited = RoomEditing.setLength(of: "w1", to: 3.5, in: scan)
        XCTAssertEqual(edited.walls[1].length, 3.5, accuracy: 1e-9)
        XCTAssertEqual(edited.walls[3].length, 3.5, accuracy: 1e-9)
        XCTAssertEqual(edited.walls[0].length, 4, accuracy: 1e-9)
    }

    func testUnknownWallOrNonsenseLengthChangesNothing() {
        let r = room()
        XCTAssertEqual(RoomEditing.setLength(of: "nope", to: 5, in: r), r)
        XCTAssertEqual(RoomEditing.setLength(of: "w0", to: 0, in: r), r)
    }

    func testCeilingHeightAppliesToAllWalls() {
        let edited = RoomEditing.setCeilingHeight(2.85, in: room())
        XCTAssertTrue(edited.walls.allSatisfy { abs($0.height - 2.85) < 1e-9 })
    }

    func testMoveAndRotateFurniture() {
        var edited = RoomEditing.move(objectId: "s", to: Point2(x: 1.2, z: 2.1), in: room())
        XCTAssertEqual(edited.objects[0].center.x, 1.2, accuracy: 1e-9)
        XCTAssertEqual(edited.objects[0].center.z, 2.1, accuracy: 1e-9)
        XCTAssertEqual(edited.objects[0].center.y, 0.4, accuracy: 1e-9)
        edited = RoomEditing.rotate(objectId: "s", byDegrees: 90, in: edited)
        XCTAssertEqual(edited.objects[0].yaw, .pi / 2, accuracy: 1e-9)
    }

    func testDeleteFurnitureAndOpenings() {
        XCTAssertTrue(RoomEditing.deleteObject("s", in: room()).objects.isEmpty)
        XCTAssertTrue(RoomEditing.deleteOpening("d", in: room()).openings.isEmpty)
    }

    func testHitTestingFindsFurnitureUnderAPoint() {
        let scan = room()
        XCTAssertEqual(RoomEditing.object(at: Point2(x: 2.8, z: 1.3), in: scan)?.id, "s")
        XCTAssertNil(RoomEditing.object(at: Point2(x: 3.5, z: 2.5), in: scan))
    }

    func testHitTestingFindsTheNearestWall() {
        XCTAssertEqual(RoomEditing.wall(near: Point2(x: 2, z: 0.1), in: room(), tolerance: 0.3)?.id, "w0")
        XCTAssertNil(RoomEditing.wall(near: Point2(x: 2, z: 1.5), in: room(), tolerance: 0.3))
    }
}
