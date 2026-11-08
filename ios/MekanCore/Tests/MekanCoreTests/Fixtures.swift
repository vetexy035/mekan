import Foundation
@testable import MekanCore

/// Builds a closed polygon room from corner points (in order), one wall per edge.
func roomFromCorners(_ corners: [(Double, Double)], height: Double = 2.7) -> RoomScan {
    var walls: [Wall] = []
    for i in corners.indices {
        let a = corners[i]
        let b = corners[(i + 1) % corners.count]
        walls.append(Wall(id: "w\(i)", start: Point2(x: a.0, z: a.1), end: Point2(x: b.0, z: b.1), height: height))
    }
    return RoomScan(name: "Test", walls: walls)
}

func rotated(_ corners: [(Double, Double)], degrees: Double) -> [(Double, Double)] {
    let r = degrees * .pi / 180
    return corners.map { (x, z) in (x * cos(r) - z * sin(r), x * sin(r) + z * cos(r)) }
}

let rect4x3: [(Double, Double)] = [(0, 0), (4, 0), (4, 3), (0, 3)]
