import XCTest
@testable import MekanCore

/// Two rooms scanned in one session share coordinates:
/// living room 4 × 3 at the origin, kitchen 3 × 3 right next to it (x 4…7).
final class HomePlanTests: XCTestCase {
    private func rooms() -> [RoomScan] {
        var living = roomFromCorners(rect4x3)
        living.name = "Salon"
        living.objects = [RoomObject(id: "s", category: "sofa", center: Point3(x: 2, y: 0.4, z: 1),
                                     size: Point3(x: 2, y: 0.8, z: 0.9), yaw: 0)]
        var kitchen = roomFromCorners([(4, 0), (7, 0), (7, 3), (4, 3)])
        kitchen.name = "Mutfak"
        kitchen.walls = kitchen.walls.map { var w = $0; w.id = "k" + w.id; return w }
        return [living, kitchen]
    }

    func testTotalAreaAddsUpRooms() {
        let r = rooms()
        let home = HomePlan(name: "Ev", roomIDs: r.map(\.id))
        XCTAssertEqual(home.totalArea(rooms: r), 21, accuracy: 1e-9)
    }

    func testMergedScanHasEveryWallAndObjectForDrawing() {
        let merged = HomePlan.mergedScan(name: "Ev", rooms: rooms())
        XCTAssertEqual(merged.walls.count, 8)
        XCTAssertEqual(merged.objects.count, 1)
        XCTAssertEqual(Set(merged.walls.map(\.id)).count, 8) // ids stay unique
    }

    func testRoomLabelsSitInsideEachRoom() {
        let labels = HomePlan.roomLabels(rooms: rooms())
        XCTAssertEqual(labels.count, 2)
        XCTAssertEqual(labels[0].text, "Salon · 12.0 m²")
        XCTAssertEqual(labels[0].position.x, 2, accuracy: 1e-9)
        XCTAssertEqual(labels[1].position.x, 5.5, accuracy: 1e-9)
        XCTAssertEqual(labels[1].position.z, 1.5, accuracy: 1e-9)
    }

    func testOverallFootprint() {
        let size = HomePlan.footprint(rooms: rooms())
        XCTAssertEqual(size.width, 7, accuracy: 1e-9)
        XCTAssertEqual(size.depth, 3, accuracy: 1e-9)
    }

    func testRoundTripsThroughJSON() throws {
        let home = HomePlan(name: "Ev", roomIDs: [UUID(), UUID()])
        let back = try RoomScan.decoder.decode(HomePlan.self, from: RoomScan.encoder.encode(home))
        XCTAssertEqual(back, home)
    }
}
