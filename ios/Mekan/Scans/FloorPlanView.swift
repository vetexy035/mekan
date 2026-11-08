import SwiftUI
import MekanCore

/// Top-down 2D plan drawn from the scan: walls with their lengths, doors/windows
/// and labeled furniture footprints.
struct FloorPlanView: View {
    let scan: RoomScan
    var showLabels = true

    var body: some View {
        Canvas { ctx, size in
            let pts = scan.walls.flatMap { [$0.start, $0.end] }
            guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
                  let minZ = pts.map(\.z).min(), let maxZ = pts.map(\.z).max() else { return }

            // Extra margin so wall-length labels outside the walls stay visible.
            let pad: CGFloat = showLabels ? 44 : 16
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
            var walls = Path(), weakWalls = Path()
            for w in scan.walls {
                // Low-confidence walls are drawn dashed orange: check these with a tape measure.
                if w.confidence == .low {
                    weakWalls.move(to: p(w.start.x, w.start.z)); weakWalls.addLine(to: p(w.end.x, w.end.z))
                } else {
                    walls.move(to: p(w.start.x, w.start.z)); walls.addLine(to: p(w.end.x, w.end.z))
                }
            }
            ctx.stroke(walls, with: .color(.primary), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            ctx.stroke(weakWalls, with: .color(.orange), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 5]))

            // Doors and windows as colored marks on their wall
            let wallsById = Dictionary(scan.walls.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for o in scan.openings {
                guard let id = o.wallId, let w = wallsById[id], w.length > 0 else { continue }
                let dx = (w.end.x - w.start.x) / w.length, dz = (w.end.z - w.start.z) / w.length
                let a = p(o.center.x - dx * o.width / 2, o.center.z - dz * o.width / 2)
                let b = p(o.center.x + dx * o.width / 2, o.center.z + dz * o.width / 2)
                var mark = Path(); mark.move(to: a); mark.addLine(to: b)
                let color: Color = o.kind == .window ? .cyan : .orange
                ctx.stroke(mark, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .butt))
            }

            guard showLabels else { return }

            // Wall lengths, outside each wall
            let center = PlanGeometry.centroid(of: scan.walls)
            let offset = Double(18 / scale) // ~18 pt away from the wall
            for w in scan.walls where w.length * scale > 28 {
                let a = PlanGeometry.labelAnchor(for: w, roomCenter: center, offset: offset)
                let label = Text(PlanGeometry.lengthLabel(w.length))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                ctx.draw(label, at: p(a.x, a.z))
            }

            // Furniture names, only when the footprint is big enough to hold them
            for o in scan.objects where min(o.size.x, o.size.z) * scale > 22 {
                let label = Text(o.turkishName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                ctx.draw(label, at: p(o.center.x, o.center.z))
            }
        }
        .accessibilityLabel("Oda planı")
    }
}

/// Full-screen plan; pinch to zoom for small walls and furniture.
struct FloorPlanFullScreen: View {
    @Environment(\.dismiss) private var dismiss
    let scan: RoomScan
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                FloorPlanView(scan: scan)
                    .frame(width: 360 * zoom * pinch, height: 560 * zoom * pinch)
            }
            .gesture(MagnificationGesture()
                .updating($pinch) { v, s, _ in s = v }
                .onEnded { zoom = min(max(zoom * $0, 1), 4) })
            .navigationTitle(scan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Kapat") { dismiss() } } }
        }
    }
}
