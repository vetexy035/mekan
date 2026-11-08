import Foundation

/// Top-down plan as an AutoCAD R12 ASCII DXF: millimeters, Y up (RoomPlan's −Z),
/// one layer per kind (walls, doors, windows, furniture, dimensions, text).
/// Text is transliterated to ASCII because R12 readers don't agree on code pages.
public enum PlanDXF {
    public static func make(scan: RoomScan) -> String {
        var out = ""
        func pair(_ code: Int, _ value: String) { out += "\(String(format: "%3d", code))\n\(value)\n" }
        func mm(_ meters: Double) -> String { String(format: "%.1f", meters * 1000) }

        func line(_ layer: String, _ a: Point2, _ b: Point2) {
            pair(0, "LINE"); pair(8, layer)
            pair(10, mm(a.x)); pair(20, mm(-a.z)); pair(30, "0.0")
            pair(11, mm(b.x)); pair(21, mm(-b.z)); pair(31, "0.0")
        }
        func text(_ layer: String, _ at: Point2, _ s: String, height: Double) {
            pair(0, "TEXT"); pair(8, layer)
            pair(10, mm(at.x)); pair(20, mm(-at.z)); pair(30, "0.0")
            pair(40, mm(height)); pair(1, ascii(s))
            // Centered on the insertion point.
            pair(72, "1"); pair(73, "2")
            pair(11, mm(at.x)); pair(21, mm(-at.z)); pair(31, "0.0")
        }

        // Layers with AutoCAD color numbers.
        let layers: [(String, Int)] = [("DUVAR", 7), ("KAPI", 30), ("PENCERE", 4), ("ESYA", 5), ("OLCU", 1), ("YAZI", 7)]
        pair(0, "SECTION"); pair(2, "TABLES")
        pair(0, "TABLE"); pair(2, "LAYER"); pair(70, "\(layers.count)")
        for (name, color) in layers {
            pair(0, "LAYER"); pair(2, name); pair(70, "0"); pair(62, "\(color)"); pair(6, "CONTINUOUS")
        }
        pair(0, "ENDTAB"); pair(0, "ENDSEC")

        pair(0, "SECTION"); pair(2, "ENTITIES")

        for w in scan.walls { line("DUVAR", w.start, w.end) }

        let byId = Dictionary(scan.walls.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for o in scan.openings where o.kind != .opening {
            guard let id = o.wallId, let w = byId[id], w.length > 0 else { continue }
            let dx = (w.end.x - w.start.x) / w.length, dz = (w.end.z - w.start.z) / w.length
            line(o.kind == .window ? "PENCERE" : "KAPI",
                 Point2(x: o.center.x - dx * o.width / 2, z: o.center.z - dz * o.width / 2),
                 Point2(x: o.center.x + dx * o.width / 2, z: o.center.z + dz * o.width / 2))
        }

        for o in scan.objects {
            let hw = o.size.x / 2, hd = o.size.z / 2, c = cos(o.yaw), s = sin(o.yaw)
            let corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)].map { dx, dz in
                Point2(x: o.center.x + dx * c + dz * s, z: o.center.z - dx * s + dz * c)
            }
            for i in 0..<4 { line("ESYA", corners[i], corners[(i + 1) % 4]) }
            text("ESYA", Point2(x: o.center.x, z: o.center.z), o.turkishName, height: 0.08)
        }

        let center = PlanGeometry.centroid(of: scan.walls)
        for w in scan.walls {
            text("OLCU", PlanGeometry.labelAnchor(for: w, roomCenter: center, offset: 0.25),
                 PlanGeometry.lengthLabel(w.length), height: 0.1)
        }

        if let maxZ = scan.walls.flatMap({ [$0.start.z, $0.end.z] }).min(),
           let minX = scan.walls.flatMap({ [$0.start.x, $0.end.x] }).min() {
            // Title above the plan (smallest z is the top in Y-up).
            pair(0, "TEXT"); pair(8, "YAZI")
            pair(10, mm(minX)); pair(20, mm(-maxZ + 0.6)); pair(30, "0.0")
            pair(40, mm(0.18)); pair(1, ascii(scan.name))
        }

        pair(0, "ENDSEC")
        pair(0, "EOF")
        return out
    }

    /// Turkish letters to their closest ASCII; anything else non-ASCII becomes "?".
    static func ascii(_ s: String) -> String {
        let map: [Character: String] = ["ç": "c", "Ç": "C", "ğ": "g", "Ğ": "G", "ı": "i", "İ": "I",
                                        "ö": "o", "Ö": "O", "ş": "s", "Ş": "S", "ü": "u", "Ü": "U",
                                        "²": "2", "×": "x", "–": "-", "·": "-"]
        return s.map { ch in
            if let r = map[ch] { return r }
            return ch.isASCII ? String(ch) : "?"
        }.joined()
    }
}
