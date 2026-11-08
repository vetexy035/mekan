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
    @Published private(set) var homes: [HomePlan] = []

    private let root: URL
    private let homesRoot: URL
    private let fm = FileManager.default

    init() {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("scans", isDirectory: true)
        homesRoot = docs.appendingPathComponent("homes", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        try? fm.createDirectory(at: homesRoot, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        scans = dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("scan.json")) else { return nil }
            return try? RoomScan.decoder.decode(RoomScan.self, from: data)
        }
        .sorted { $0.capturedAt > $1.capturedAt }

        let homeDirs = (try? fm.contentsOfDirectory(at: homesRoot, includingPropertiesForKeys: nil)) ?? []
        homes = homeDirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("home.json")) else { return nil }
            return try? RoomScan.decoder.decode(HomePlan.self, from: data)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: Homes (multi-room)

    func homeFolder(_ id: UUID) -> URL { homesRoot.appendingPathComponent(id.uuidString, isDirectory: true) }
    func homeModelURL(_ id: UUID) -> URL { homeFolder(id).appendingPathComponent("home.usdz") }
    func home(_ id: UUID) -> HomePlan? { homes.first { $0.id == id } }
    func rooms(of home: HomePlan) -> [RoomScan] { home.roomIDs.compactMap { scan($0) } }

    /// Merges rooms scanned in one session with Apple's StructureBuilder and saves
    /// each room as a normal scan plus a HomePlan tying them together. If merging
    /// fails, the rooms are still saved in their shared session coordinates.
    func saveHome(name: String, rooms captured: [RoomScanner.Result]) async throws -> UUID {
        var aligned = captured.map(\.room)
        var merged = false
        let homeId = UUID()
        try fm.createDirectory(at: homeFolder(homeId), withIntermediateDirectories: true)
        do {
            let structure = try await StructureBuilder(options: [.beautifyObjects])
                .capturedStructure(from: aligned)
            if structure.rooms.count == aligned.count { aligned = structure.rooms }
            try? structure.export(to: homeModelURL(homeId))
            merged = true
        } catch {
            merged = false // keep the raw rooms; they already share coordinates
        }

        var usedNames: [String: Int] = [:]
        var ids: [UUID] = []
        for (i, room) in aligned.enumerated() {
            let base = RoomTypeNames.turkish(RoomScanConverter.roomType(of: room)) ?? "Oda \(i + 1)"
            usedNames[base, default: 0] += 1
            let roomName = usedNames[base]! > 1 ? "\(base) \(usedNames[base]!)" : base
            let photo = i < captured.count ? captured[i].photo : nil
            ids.append(try save(room: room, photo: photo, name: "\(name) – \(roomName)"))
        }

        let home = HomePlan(id: homeId, name: name, roomIDs: ids, mergedByStructureBuilder: merged)
        try RoomScan.encoder.encode(home).write(to: homeFolder(homeId).appendingPathComponent("home.json"))
        reload()
        return homeId
    }

    func deleteHome(_ id: UUID, includingRooms: Bool) {
        if includingRooms, let h = home(id) { h.roomIDs.forEach { try? fm.removeItem(at: folder($0)) } }
        try? fm.removeItem(at: homeFolder(id))
        reload()
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
