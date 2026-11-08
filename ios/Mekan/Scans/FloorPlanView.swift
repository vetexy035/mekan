import SwiftUI
import MekanCore

/// Maps room coordinates (meters, XZ) to plan view points and back.
/// Fit to the walls only, so dragging furniture never rescales the plan.
struct PlanTransform {
    let minX: Double, minZ: Double, scale: Double, offX: Double, offZ: Double

    init?(scan: RoomScan, size: CGSize, pad: CGFloat) {
        let pts = scan.walls.flatMap { [$0.start, $0.end] }
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minZ = pts.map(\.z).min(), let maxZ = pts.map(\.z).max(), size.width > 2 * pad else { return nil }
        let spanX = max(maxX - minX, 0.01), spanZ = max(maxZ - minZ, 0.01)
        let scale = min((size.width - 2 * pad) / spanX, (size.height - 2 * pad) / spanZ)
        self.minX = minX; self.minZ = minZ; self.scale = scale
        offX = (size.width - spanX * scale) / 2
        offZ = (size.height - spanZ * scale) / 2
    }

    func screen(_ x: Double, _ z: Double) -> CGPoint {
        CGPoint(x: offX + (x - minX) * scale, y: offZ + (z - minZ) * scale)
    }

    func world(_ p: CGPoint) -> Point2 {
        Point2(x: (p.x - offX) / scale + minX, z: (p.y - offZ) / scale + minZ)
    }

    static func pad(showLabels: Bool) -> CGFloat { showLabels ? 44 : 16 }
}

/// Top-down 2D plan drawn from the scan: walls with their lengths, doors/windows
/// and labeled furniture footprints.
struct FloorPlanView: View {
    let scan: RoomScan
    var showLabels = true
    /// Wall stretches to highlight in green (e.g. where a new sofa fits).
    var highlights: [FitSpot] = []
    /// Editor selection, drawn emphasized.
    var selectedObjectId: String?
    var selectedWallId: String?
    /// Home plans: room name and area at the middle of each room.
    var roomLabels: [HomePlan.RoomLabel] = []

    var body: some View {
        Canvas { ctx, size in
            // Extra margin so wall-length labels outside the walls stay visible.
            guard let t = PlanTransform(scan: scan, size: size, pad: PlanTransform.pad(showLabels: showLabels)) else { return }
            let scale = t.scale
            func p(_ x: Double, _ z: Double) -> CGPoint { t.screen(x, z) }

            // Furniture footprints
            for o in scan.objects {
                let hw = o.size.x / 2, hd = o.size.z / 2
                let c = cos(o.yaw), s = sin(o.yaw)
                let corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)].map { (dx, dz) in
                    p(o.center.x + dx * c + dz * s, o.center.z - dx * s + dz * c)
                }
                var path = Path(); path.addLines(corners); path.closeSubpath()
                let selected = o.id == selectedObjectId
                ctx.fill(path, with: .color(.accentColor.opacity(selected ? 0.4 : 0.18)))
                ctx.stroke(path, with: .color(.accentColor.opacity(selected ? 1 : 0.6)), lineWidth: selected ? 3 : 1)
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

            if let id = selectedWallId, let w = wallsById[id] {
                var sel = Path(); sel.move(to: p(w.start.x, w.start.z)); sel.addLine(to: p(w.end.x, w.end.z))
                ctx.stroke(sel, with: .color(.accentColor), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }

            for label in roomLabels {
                let text = Text(label.text).font(.system(size: 12, weight: .bold)).foregroundStyle(.primary)
                let at = p(label.position.x, label.position.z)
                let resolved = ctx.resolve(text)
                let size = resolved.measure(in: CGSize(width: 400, height: 40))
                let box = CGRect(x: at.x - size.width / 2 - 6, y: at.y - size.height / 2 - 3,
                                 width: size.width + 12, height: size.height + 6)
                ctx.fill(Path(roundedRect: box, cornerRadius: 6), with: .color(Color(.systemBackground).opacity(0.85)))
                ctx.draw(resolved, at: at)
            }

            for spot in highlights {
                var band = Path(); band.move(to: p(spot.start.x, spot.start.z)); band.addLine(to: p(spot.end.x, spot.end.z))
                ctx.stroke(band, with: .color(.green.opacity(0.75)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
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
