import XCTest
@testable import MekanCore

final class PromptBuilderTests: XCTestCase {
    private func sampleScan() -> RoomScan {
        var scan = roomFromCorners(rect4x3)
        scan.openings = [
            Opening(id: "w", kind: .window, wallId: "w0", center: Point3(x: 2, y: 1.5, z: 0), width: 1.2, height: 1.2),
        ]
        scan.objects = [
            RoomObject(id: "s", category: "sofa", center: Point3(x: 2, y: 0.4, z: 2), size: Point3(x: 2, y: 0.8, z: 0.9), yaw: 0),
            RoomObject(id: "c1", category: "chair", center: Point3(x: 1, y: 0.4, z: 1), size: Point3(x: 0.5, y: 0.9, z: 0.5), yaw: 0),
            RoomObject(id: "c2", category: "chair", center: Point3(x: 3, y: 0.4, z: 1), size: Point3(x: 0.5, y: 0.9, z: 0.5), yaw: 0),
        ]
        return scan
    }

    func testPromptStatesDimensionsInMeters() {
        let p = PromptBuilder.prompt(for: sampleScan(), style: .japandi)
        XCTAssertTrue(p.contains("4.0 m x 3.0 m"), p)
        XCTAssertTrue(p.contains("2.7 m ceiling"), p)
    }

    func testPromptListsOpeningsAndGroupedFurniture() {
        let p = PromptBuilder.prompt(for: sampleScan(), style: .japandi)
        XCTAssertTrue(p.contains("1 window"), p)
        XCTAssertTrue(p.contains("2 chairs"), p)
        XCTAssertTrue(p.contains("1 sofa"), p)
    }

    func testPromptIncludesStyleAndPreservationInstruction() {
        let p = PromptBuilder.prompt(for: sampleScan(), style: .scandinavian)
        XCTAssertTrue(p.contains(DesignStyle.scandinavian.promptFragment), p)
        XCTAssertTrue(p.lowercased().contains("keep"), p)
    }

    func testExtraNoteIsAppendedWhenPresent() {
        let p = PromptBuilder.prompt(for: sampleScan(), style: .modern, note: "add plants")
        XCTAssertTrue(p.hasSuffix("Additional request: add plants"), p)
        let q = PromptBuilder.prompt(for: sampleScan(), style: .modern, note: "  ")
        XCTAssertFalse(q.contains("Additional request"), q)
    }
}
