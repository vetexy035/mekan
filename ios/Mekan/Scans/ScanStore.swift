import Foundation
import UIKit
import RoomPlan
import MekanCore

/// Persists scans under Documents/scans/<id>/:
///   scan.json   our RoomScan (v1)
///   room.usdz   3D model from RoomPlan
///   photo.jpg   camera frame from the end of the scan
///   renders/    AI-generated designs
@MainActor
final class ScanStore: ObservableObject {
    @Published private(set) var scans: [RoomScan] = []

    private let root: URL
    private let fm = FileManager.default

    init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("scans", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        scans = dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("scan.json")) else { return nil }
            return try? RoomScan.decoder.decode(RoomScan.self, from: data)
        }
        .sorted { $0.capturedAt > $1.capturedAt }
    }

    func scan(_ id: UUID) -> RoomScan? { scans.first { $0.id == id } }

    @discardableResult
    func save(room: CapturedRoom, photo: UIImage?, name: String) throws -> UUID {
        let scan = RoomScanConverter.convert(room, name: name)
        let dir = folder(scan.id)
        try fm.createDirectory(at: dir.appendingPathComponent("renders"), withIntermediateDirectories: true)
        try RoomScan.encoder.encode(scan).write(to: dir.appendingPathComponent("scan.json"))
        try room.export(to: modelURL(scan.id), exportOptions: .parametric)
        // The raw scanned surface: furniture keeps its real shape instead of boxes.
        try? room.export(to: meshURL(scan.id), exportOptions: .mesh)
        // Keep RoomPlan's own data so the 3D file can be re-exported later
        // (e.g. with custom furniture models) without rescanning.
        try? JSONEncoder().encode(room).write(to: folder(scan.id).appendingPathComponent("captured-room.json"))
        if let jpg = photo?.jpegData(compressionQuality: 0.85) {
            try jpg.write(to: photoURL(scan.id))
        }
        reload()
        return scan.id
    }

    /// Saves a hand-corrected scan. The first edit keeps the untouched scan as
    /// scan.original.json so the user can always go back.
    func update(_ scan: RoomScan) throws {
        let dir = folder(scan.id)
        let current = dir.appendingPathComponent("scan.json")
        let original = dir.appendingPathComponent("scan.original.json")
        if !fm.fileExists(atPath: original.path), fm.fileExists(atPath: current.path) {
            try fm.copyItem(at: current, to: original)
        }
        try RoomScan.encoder.encode(scan).write(to: current)
        reload()
    }

    func hasOriginal(_ id: UUID) -> Bool {
        fm.fileExists(atPath: folder(id).appendingPathComponent("scan.original.json").path)
    }

    func original(_ id: UUID) -> RoomScan? {
        guard let data = try? Data(contentsOf: folder(id).appendingPathComponent("scan.original.json")) else { return nil }
        return try? RoomScan.decoder.decode(RoomScan.self, from: data)
    }

    func delete(_ id: UUID) {
        try? fm.removeItem(at: folder(id))
        reload()
    }

    func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    func modelURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("room.usdz") }
    func photoURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("photo.jpg") }
    func meshURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("room-mesh.usdz") }
    func hasMesh(_ id: UUID) -> Bool { fm.fileExists(atPath: meshURL(id).path) }

    func photo(_ id: UUID) -> UIImage? { UIImage(contentsOfFile: photoURL(id).path) }

    // MARK: Design (wall color, floor)

    func design(_ id: UUID) -> ScanDesign {
        let url = folder(id).appendingPathComponent("design.json")
        guard let data = try? Data(contentsOf: url),
              let d = try? JSONDecoder().decode(ScanDesign.self, from: data) else { return ScanDesign() }
        return d
    }

    func setDesign(_ design: ScanDesign, for id: UUID) {
        let url = folder(id).appendingPathComponent("design.json")
        try? JSONEncoder().encode(design).write(to: url)
        objectWillChange.send()
    }

    // MARK: Renders

    func renders(_ id: UUID) -> [URL] {
        let dir = folder(id).appendingPathComponent("renders")
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files.filter { $0.pathExtension == "png" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func addRender(_ png: Data, to id: UUID, style: DesignStyle) throws -> URL {
        let stamp = Int(Date().timeIntervalSince1970)
        let url = folder(id).appendingPathComponent("renders/\(stamp)-\(style.rawValue).png")
        try png.write(to: url)
        objectWillChange.send()
        return url
    }
}
