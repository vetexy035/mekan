import Foundation

public enum DesignStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case modern, scandinavian, japandi, industrial, bohemian, classic, midCentury

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .modern: "Modern minimal"
        case .scandinavian: "İskandinav"
        case .japandi: "Japandi"
        case .industrial: "Endüstriyel"
        case .bohemian: "Bohem"
        case .classic: "Klasik"
        case .midCentury: "Mid-century"
        }
    }

    public var promptFragment: String {
        switch self {
        case .modern: "a modern minimalist style with clean lines, neutral palette and hidden storage"
        case .scandinavian: "a Scandinavian style with light oak wood, white walls, soft textiles and cozy lighting"
        case .japandi: "a Japandi style blending Japanese and Scandinavian design, natural wood, linen, muted earth tones"
        case .industrial: "an industrial loft style with exposed brick, black metal, concrete and Edison bulbs"
        case .bohemian: "a bohemian style with layered rugs, rattan, plants and warm colorful textiles"
        case .classic: "a classic elegant style with moldings, symmetrical layout, rich fabrics and brass details"
        case .midCentury: "a mid-century modern style with walnut furniture, tapered legs and mustard and teal accents"
        }
    }
}

/// Turns a scan's measurements and contents into a text prompt for image models.
public enum PromptBuilder {
    public static func prompt(for scan: RoomScan, style: DesignStyle, note: String? = nil) -> String {
        let m = RoomMeasurements(scan: scan)
        var parts: [String] = []

        parts.append("Photorealistic interior design photo of the same room, redesigned in \(style.promptFragment).")
        parts.append("Room: \(f(m.length)) m x \(f(m.width)) m with a \(f(m.ceilingHeight)) m ceiling, about \(f(m.floorArea)) m² of floor.")

        let openings = [count(m.doorCount, "door"), count(m.windowCount, "window")].compactMap { $0 }
        if !openings.isEmpty {
            parts.append("Openings: \(openings.joined(separator: ", ")).")
        }

        let furniture = Dictionary(grouping: scan.objects, by: \.category)
            .sorted { $0.key < $1.key }
            .compactMap { count($0.value.count, displayName(for: $0.key)) }
        if !furniture.isEmpty {
            parts.append("Current furniture: \(furniture.joined(separator: ", ")).")
        }

        parts.append("Keep the room's exact proportions, wall layout, window and door positions and the camera viewpoint; change only furniture, materials, colors and lighting.")

        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            parts.append("Additional request: \(note)")
        }
        return parts.joined(separator: " ")
    }

    private static func f(_ v: Double) -> String { String(format: "%.1f", v) }

    private static func count(_ n: Int, _ noun: String) -> String? {
        guard n > 0 else { return nil }
        return n == 1 ? "1 \(noun)" : "\(n) \(noun)s"
    }

    private static func displayName(for category: String) -> String {
        switch category {
        case "storage": "storage unit"
        case "washerDryer": "washer-dryer"
        case "television": "TV"
        case "stairs": "staircase"
        default: category
        }
    }
}
