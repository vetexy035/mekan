import SwiftUI
import MekanCore

/// Top-down 2D plan drawn from the scan: walls, doors/windows and furniture footprints.
struct FloorPlanView: View {
    let scan: RoomScan

    var body: some View {
        Canvas { ctx, size in
            let pts = scan.walls.flatMap { [$0.start, $0.end] }
            guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
                  let minZ = pts.map(\.z).min(), let maxZ = pts.map(\.z).max() else { return }

            let pad: CGFloat = 16
            let spanX = max(maxX - minX, 0.01), spanZ = max(maxZ - minZ, 0.01)
            let scale = min((size.width - 2 * pad) / spanX, (size.height - 2 * pad) / spanZ)
            let offX = (size.width - spanX * scale) / 2, offZ = (size.height - spanZ * scale) / 2
            func p(_ x: Double, _ z: Double) -> CGPoint {
                CGPoint(x: offX + (x - minX) * scale, y: offZ + (z - minZ) * scale)
            }

            // Furniture footprints
            for o in scan.objects {
                let hw = o.size.x / 2, hd = o.size.z / 2
                let c = cos(o.yaw), s = sin(o.yaw)
                let corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)].map { (dx, dz) in
                    p(o.center.x + dx * c + dz * s, o.center.z - dx * s + dz * c)
                }
                var path = Path(); path.addLines(corners); path.closeSubpath()
                ctx.fill(path, with: .color(.accentColor.opacity(0.18)))
                ctx.stroke(path, with: .color(.accentColor.opacity(0.6)), lineWidth: 1)
            }

            // Walls
            var walls = Path()
            for w in scan.walls {
                walls.move(to: p(w.start.x, w.start.z)); walls.addLine(to: p(w.end.x, w.end.z))
            }
            ctx.stroke(walls, with: .color(.primary), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            // Doors and windows as colored marks on their wall
            let wallsById = Dictionary(uniqueKeysWithValues: scan.walls.map { ($0.id, $0) })
            for o in scan.openings {
                guard let id = o.wallId, let w = wallsById[id], w.length > 0 else { continue }
                let dx = (w.end.x - w.start.x) / w.length, dz = (w.end.z - w.start.z) / w.length
                let a = p(o.center.x - dx * o.width / 2, o.center.z - dz * o.width / 2)
                let b = p(o.center.x + dx * o.width / 2, o.center.z + dz * o.width / 2)
                var mark = Path(); mark.move(to: a); mark.addLine(to: b)
                let color: Color = o.kind == .window ? .cyan : .orange
                ctx.stroke(mark, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .butt))
            }
        }
        .accessibilityLabel("Oda planı")
    }
}
