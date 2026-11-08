import XCTest
@testable import MekanCore

final class RoomScanCodingTests: XCTestCase {
    func testRoundTripPreservesScan() throws {
        var scan = roomFromCorners(rect4x3)
        scan.objects = [RoomObject(id: "t", category: "table", center: Point3(x: 1, y: 0.4, z: 1),
                                   size: Point3(x: 1.2, y: 0.75, z: 0.8), yaw: 0.5)]
        let data = try RoomScan.encoder.encode(scan)
        let decoded = try RoomScan.decoder.decode(RoomScan.self, from: data)
        XCTAssertEqual(decoded, scan)
    }

    func testEncodesSchemaVersion() throws {
        let data = try RoomScan.encoder.encode(RoomScan(name: "x"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
    }
}
