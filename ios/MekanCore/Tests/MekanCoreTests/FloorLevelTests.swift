import XCTest
@testable import MekanCore

/// RoomPlan heights are relative to where the phone started (~1.3 m above the floor),
/// so the floor is usually well below y = 0.
final class FloorLevelTests: XCTestCase {
    private let floorY = -1.32

    private func door(bottom: Double) -> Opening {
        Opening(id: "d", kind: .door, wallId: nil, center: Point3(x: 0, y: bottom + 1.0, z: 0), width: 0.9, height: 2.0)
    }

    private func object(_ cat: String, bottom: Double, height: Double) -> RoomObject {
        RoomObject(id: cat, category: cat, center: Point3(x: 1, y: bottom + height / 2, z: 1),
                   size: Point3(x: 1, y: height, z: 1), yaw: 0)
    }

    func testStoredFloorLevelWins() {
        var scan = roomFromCorners(rect4x3)
        scan.floorY = floorY
        scan.openings = [door(bottom: 0)]
        XCTAssertEqual(scan.estimatedFloorY, floorY, accuracy: 1e-9)
    }

    func testFloorFromDoorBottomsWhenNotStored() {
        var scan = roomFromCorners(rect4x3)
        scan.openings = [door(bottom: floorY), door(bottom: floorY + 0.02)]
        XCTAssertEqual(scan.estimatedFloorY, floorY, accuracy: 0.011)
    }

    func testFloorFromLowestFurnitureWhenNoDoors() {
        var scan = roomFromCorners(rect4x3)
        scan.objects = [object("sofa", bottom: floorY + 0.03, height: 0.8),
                        object("table", bottom: floorY, height: 0.75),
                        object("television", bottom: floorY + 1.1, height: 0.6)]
        XCTAssertEqual(scan.estimatedFloorY, floorY, accuracy: 1e-9)
    }

    func testEmptyScanFloorIsZero() {
        XCTAssertEqual(roomFromCorners(rect4x3).estimatedFloorY, 0)
    }

    func testFloorLevelSurvivesEncoding() throws {
        var scan = roomFromCorners(rect4x3)
        scan.floorY = floorY
        let decoded = try RoomScan.decoder.decode(RoomScan.self, from: RoomScan.encoder.encode(scan))
        XCTAssertEqual(decoded.floorY, floorY)
    }

    func testOldScansWithoutFloorLevelStillDecode() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: RoomScan.encoder.encode(roomFromCorners(rect4x3))) as? [String: Any])
        json.removeValue(forKey: "floorY")
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertNil(try RoomScan.decoder.decode(RoomScan.self, from: data).floorY)
    }

    func testFurnitureNearTheFloorSnapsOntoIt() {
        let sofa = object("sofa", bottom: floorY + 0.12, height: 0.8)
        // Height above the floor of the object's center after snapping.
        XCTAssertEqual(FloorLevel.restingCenterHeight(of: sofa, floorY: floorY), 0.4, accuracy: 1e-9)
        let sunk = object("table", bottom: floorY - 0.2, height: 0.75)
        XCTAssertEqual(FloorLevel.restingCenterHeight(of: sunk, floorY: floorY), 0.375, accuracy: 1e-9)
    }

    func testWallMountedItemsKeepTheirHeight() {
        let tv = object("television", bottom: floorY + 1.1, height: 0.6)
        XCTAssertEqual(FloorLevel.restingCenterHeight(of: tv, floorY: floorY), 1.4, accuracy: 1e-9)
    }

    func testOpeningHeightIsMeasuredFromTheFloor() {
        let window = Opening(id: "w", kind: .window, wallId: nil, center: Point3(x: 0, y: floorY + 1.5, z: 0), width: 1.2, height: 1.2)
        XCTAssertEqual(FloorLevel.centerHeight(of: window, floorY: floorY), 1.5, accuracy: 1e-9)
        // Doors always stand on the floor.
        let d = door(bottom: floorY + 0.05)
        XCTAssertEqual(FloorLevel.centerHeight(of: d, floorY: floorY), 1.0, accuracy: 1e-9)
    }
}
