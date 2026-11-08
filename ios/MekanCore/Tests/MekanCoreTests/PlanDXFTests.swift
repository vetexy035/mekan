import XCTest
@testable import MekanCore

final class PlanDXFTests: XCTestCase {
    private func dxf() -> String {
        var scan = roomFromCorners(rect4x3)
        scan.name = "Çocuk odası"
        scan.openings = [Opening(id: "d", kind: .door, wallId: "w0", center: Point3(x: 1, y: 1, z: 0), width: 0.9, height: 2)]
        scan.objects = [RoomObject(id: "s", category: "sofa", center: Point3(x: 2, y: 0.4, z: 2),
                                   size: Point3(x: 2, y: 0.8, z: 0.9), yaw: 0)]
        return PlanDXF.make(scan: scan)
    }

    /// Group-code/value pairs, so tests don't depend on whitespace.
    private func pairs(_ s: String) -> [(Int, String)] {
        let lines = s.components(separatedBy: "\n")
        return stride(from: 0, to: lines.count - 1, by: 2).compactMap { i in
            Int(lines[i].trimmingCharacters(in: .whitespaces)).map { ($0, lines[i + 1]) }
        }
    }

    func testHasEntitiesSectionAndEndsWithEOF() {
        let p = pairs(dxf())
        XCTAssertTrue(p.contains { $0 == (2, "ENTITIES") })
        XCTAssertEqual(p.last?.0, 0)
        XCTAssertEqual(p.last?.1, "EOF")
    }

    func testLinesOnSeparateLayers() {
        let p = pairs(dxf())
        // Each LINE is followed by its layer (code 8).
        var layers: [String] = []
        for (i, pair) in p.enumerated() where pair == (0, "LINE") {
            if let layer = p[(i + 1)...].first(where: { $0.0 == 8 }) { layers.append(layer.1) }
        }
        XCTAssertEqual(layers.filter { $0 == "DUVAR" }.count, 4)
        XCTAssertEqual(layers.filter { $0 == "KAPI" }.count, 1)
        XCTAssertEqual(layers.filter { $0 == "ESYA" }.count, 4)
    }

    func testCoordinatesAreMillimetersWithYUp() {
        let p = pairs(dxf())
        // Wall w0 runs (0,0)->(4,0) m: x to 4000 mm. Room depth z=3 m becomes y=-3000.
        XCTAssertTrue(p.contains { $0.0 == 11 && Double($0.1) == 4000 })
        XCTAssertTrue(p.contains { $0.0 == 20 && Double($0.1) == -3000 })
    }

    func testTextIsTransliteratedToASCII() {
        let s = dxf()
        XCTAssertTrue(s.contains("Cocuk odasi"))
        XCTAssertTrue(s.contains("4.00 m"))
        XCTAssertTrue(s.contains("Koltuk"))
        XCTAssertTrue(s.unicodeScalars.allSatisfy { $0.isASCII })
    }
}
