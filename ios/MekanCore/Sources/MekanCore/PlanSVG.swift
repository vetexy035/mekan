import Foundation

/// Top-down plan as a standalone SVG (1 unit = 1 cm), for web, Inkscape or Illustrator.
public enum PlanSVG {
    public static func make(scan: RoomScan) -> String {
        let pts = scan.walls.flatMap { [$0.start, $0.end] }
        let minX = pts.map(\.x).min() ?? 0, maxX = pts.map(\.x).max() ?? 1
        let minZ = pts.map(\.z).min() ?? 0, maxZ = pts.map(\.z).max() ?? 1
        let margin = 60.0
        let width = (maxX - minX) * 100 + 2 * margin
        let height = (maxZ - minZ) * 100 + 2 * margin + 40 // room for the title
        func x(_ v: Double) -> String { n((v - minX) * 100 + margin) }
        func z(_ v: Double) -> String { n((v - minZ) * 100 + margin + 40) }

        var out = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(n(width))mm" height="\(n(height))mm" viewBox="0 0 \(n(width)) \(n(height))">
        <style>
        .wall{stroke:#222;stroke-width:6;stroke-linecap:round}
        .door{stroke:#e8891c;stroke-width:9}
        .window{stroke:#2aa7d6;stroke-width:9}
        .furniture{fill:#3b7ddd22;stroke:#3b7ddd;stroke-width:1.5}
        text{font-family:-apple-system,Helvetica,Arial,sans-serif;fill:#222}
        .len{font-size:16px;font-weight:600;text-anchor:middle;dominant-baseline:middle}
        .name{font-size:13px;fill:#3b7ddd;text-anchor:middle;dominant-baseline:middle}
        </style>
        <rect width="100%" height="100%" fill="#fff"/>
        <text x="\(n(margin))" y="34" font-size="22" font-weight="700">\(escape(scan.name))</text>

        """

        for o in scan.objects {
            let hw = o.size.x / 2, hd = o.size.z / 2, c = cos(o.yaw), s = sin(o.yaw)
            let corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)].map { dx, dz in
                "\(x(o.center.x + dx * c + dz * s)),\(z(o.center.z - dx * s + dz * c))"
            }
            out += "<polygon class=\"furniture\" points=\"\(corners.joined(separator: " "))\"/>\n"
            out += "<text class=\"name\" x=\"\(x(o.center.x))\" y=\"\(z(o.center.z))\">\(escape(o.turkishName))</text>\n"
        }

        for w in scan.walls {
            out += "<line class=\"wall\" x1=\"\(x(w.start.x))\" y1=\"\(z(w.start.z))\" x2=\"\(x(w.end.x))\" y2=\"\(z(w.end.z))\"/>\n"
        }

        let byId = Dictionary(scan.walls.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for o in scan.openings where o.kind != .opening {
            guard let id = o.wallId, let w = byId[id], w.length > 0 else { continue }
            let dx = (w.end.x - w.start.x) / w.length, dz = (w.end.z - w.start.z) / w.length
            let cls = o.kind == .window ? "window" : "door"
            out += "<line class=\"\(cls)\" x1=\"\(x(o.center.x - dx * o.width / 2))\" y1=\"\(z(o.center.z - dz * o.width / 2))\" x2=\"\(x(o.center.x + dx * o.width / 2))\" y2=\"\(z(o.center.z + dz * o.width / 2))\"/>\n"
        }

        let center = PlanGeometry.centroid(of: scan.walls)
        for w in scan.walls {
            let a = PlanGeometry.labelAnchor(for: w, roomCenter: center, offset: 0.25)
            out += "<text class=\"len\" x=\"\(x(a.x))\" y=\"\(z(a.z))\">\(PlanGeometry.lengthLabel(w.length))</text>\n"
        }

        out += "</svg>\n"
        return out
    }

    private static func n(_ v: Double) -> String { String(format: "%.1f", v) }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
