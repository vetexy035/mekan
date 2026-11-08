import SwiftUI
import QuickLook
import MekanCore

struct HomeRoute: Hashable { let id: UUID }

/// All rooms of a multi-room scan on one plan, with per-room and total area.
struct HomePlanView: View {
    @EnvironmentObject private var store: ScanStore
    @Environment(\.dismiss) private var dismiss
    let home: HomePlan
    init(home: HomePlan) { self.home = home }

    @State private var modelURL: URL?
    @State private var shareURL: URL?
    @State private var confirmDelete = false

    var body: some View {
        let rooms = store.rooms(of: home)
        let merged = HomePlan.mergedScan(name: home.name, rooms: rooms)
        let footprint = HomePlan.footprint(rooms: rooms)
        List {
            Section {
                FloorPlanView(scan: merged, showLabels: false, roomLabels: HomePlan.roomLabels(rooms: rooms))
                    .frame(height: 340)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                if !home.mergedByStructureBuilder {
                    Label("Odalar otomatik hizalanamadı; tarama sırasındaki konumlarıyla gösteriliyor.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Özet") {
                row("Oda sayısı", "\(rooms.count)")
                row("Toplam oda alanı", String(format: "%.1f m²", home.totalArea(rooms: rooms)))
                row("Dış ölçü", String(format: "%.1f × %.1f m", max(footprint.width, footprint.depth),
                                       min(footprint.width, footprint.depth)))
            }

            Section("Odalar") {
                ForEach(rooms) { r in
                    NavigationLink(value: r.id) {
                        HStack {
                            Text(r.name)
                            Spacer()
                            Text(String(format: "%.1f m²", RoomMeasurements(scan: r).floorArea))
                                .foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }

            Section {
                if FileManager.default.fileExists(atPath: store.homeModelURL(home.id).path) {
                    Button { modelURL = store.homeModelURL(home.id) } label: {
                        Label("Evin 3D modeli", systemImage: "house")
                    }
                }
                Button { shareURL = try? writeSVG(merged) } label: {
                    Label("Ev planını SVG olarak paylaş", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Ev planını sil", systemImage: "trash")
                }
            }
        }
        .navigationTitle(home.name)
        .quickLookPreview($modelURL)
        .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        .confirmationDialog("Ev planı silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Yalnızca ev planını sil", role: .destructive) { store.deleteHome(home.id, includingRooms: false); dismiss() }
            Button("Odalarla birlikte sil", role: .destructive) { store.deleteHome(home.id, includingRooms: true); dismiss() }
        } message: {
            Text("Odalar ayrı taramalar olarak da kayıtlı. Bu işlem geri alınamaz.")
        }
    }

    private func writeSVG(_ scan: RoomScan) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mekan-ev-plani.svg")
        try Data(PlanSVG.make(scan: scan).utf8).write(to: url)
        return url
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary).monospacedDigit() }
    }
}
