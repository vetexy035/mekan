import SwiftUI
import QuickLook
import MekanCore

struct ScanDetailView: View {
    @EnvironmentObject private var store: ScanStore
    let scan: RoomScan
    init(scan: RoomScan) { self.scan = scan }

    @State private var modelURL: URL?
    @State private var showRedesign = false
    @State private var showPlan = false
    @State private var show3D = false
    @State private var showEditor = false
    @State private var shareURL: URL?
    @State private var exportError: String?

    private var m: RoomMeasurements { RoomMeasurements(scan: scan) }
    private var quality: ScanQuality { ScanQuality(scan: scan) }

    var body: some View {
        List {
            Section {
                FloorPlanView(scan: scan)
                    .frame(height: 300)
                    .contentShape(Rectangle())
                    .onTapGesture { showPlan = true }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                HStack(spacing: 16) {
                    legend(.orange, "Kapı"); legend(.cyan, "Pencere"); legend(.accentColor, "Eşya")
                }
                .font(.caption)
                Button { showEditor = true } label: {
                    Label("Planı düzenle (ölçü düzelt, eşya taşı)", systemImage: "pencil.and.ruler")
                }
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(qualityTitle).font(.subheadline.weight(.semibold))
                        Text(quality.turkishSummary).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: qualityIcon).foregroundStyle(qualityColor)
                }
            }

            Section("Ölçüler") {
                if let type = RoomTypeNames.turkish(scan.roomType) { row("Oda tipi", type) }
                row("Boy", meters(m.length))
                row("En", meters(m.width))
                row("Tavan yüksekliği", meters(m.ceilingHeight))
                row("Zemin alanı", String(format: "%.1f m²", m.floorArea) + (m.isAreaEstimated ? " (yaklaşık)" : ""))
                row("Çevre", meters(m.perimeter))
                row("Kapı / pencere", "\(m.doorCount) / \(m.windowCount)")
            }

            if !scan.objects.isEmpty {
                Section("Eşyalar") {
                    ForEach(scan.objects) { o in
                        row(o.turkishName, String(format: "%.0f × %.0f × %.0f cm", o.size.x * 100, o.size.z * 100, o.size.y * 100))
                    }
                }
            }

            Section {
                Button { show3D = true } label: {
                    Label("3D oda (mobilyalı)", systemImage: "sofa")
                }
                Button { modelURL = store.modelURL(scan.id) } label: {
                    Label("3D model (sade, kutu eşyalar)", systemImage: "cube")
                }
                if store.hasMesh(scan.id) {
                    Button { modelURL = store.meshURL(scan.id) } label: {
                        Label("3D tarama (gerçek şekiller)", systemImage: "cube.transparent")
                    }
                }
                Button { showRedesign = true } label: {
                    Label("AI ile yeniden tasarla", systemImage: "wand.and.stars")
                }
                NavigationLink { FitCheckView(scan: scan) } label: {
                    Label("Sığar mı? (yeni eşya kontrolü)", systemImage: "ruler")
                }
                NavigationLink { MaterialsView(scan: scan) } label: {
                    Label("Malzeme hesabı (boya, parke…)", systemImage: "paintbrush")
                }
                Menu {
                    Button { export { try PlanPDF.make(scan: scan, design: store.design(scan.id)) } } label: {
                        Label("PDF plan (ustaya gönder)", systemImage: "doc.richtext")
                    }
                    Button { export { try writeTemp(PlanSVG.make(scan: scan), ext: "svg") } } label: {
                        Label("SVG plan (çizim programları)", systemImage: "square.on.circle")
                    }
                    Button { export { try writeTemp(String(decoding: RoomScan.encoder.encode(scan), as: UTF8.self), ext: "json") } } label: {
                        Label("JSON ölçü verisi", systemImage: "curlybraces")
                    }
                    Button { shareURL = store.modelURL(scan.id) } label: {
                        Label("USDZ 3D model", systemImage: "cube")
                    }
                    if store.hasMesh(scan.id) {
                        Button { shareURL = store.meshURL(scan.id) } label: {
                            Label("USDZ ham tarama", systemImage: "cube.transparent")
                        }
                    }
                } label: {
                    Label("Dışa aktar / paylaş", systemImage: "square.and.arrow.up")
                }
            }

            let renders = store.renders(scan.id)
            if !renders.isEmpty {
                Section("Tasarımlar") {
                    ForEach(renders, id: \.self) { url in
                        if let img = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: img).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contextMenu { ShareLink(item: Image(uiImage: img), preview: SharePreview("Tasarım", image: Image(uiImage: img))) }
                        }
                    }
                }
            }
        }
        .navigationTitle(scan.name)
        .quickLookPreview($modelURL)
        .sheet(isPresented: $showRedesign) {
            RedesignView(scan: scan).environmentObject(store)
        }
        .fullScreenCover(isPresented: $showPlan) {
            FloorPlanFullScreen(scan: scan)
        }
        .fullScreenCover(isPresented: $show3D) {
            Room3DView(scan: scan, design: store.design(scan.id)) { store.setDesign($0, for: scan.id) }
        }
        .fullScreenCover(isPresented: $showEditor) {
            PlanEditorView(scan: scan).environmentObject(store)
        }
        .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        .alert("Dışa aktarılamadı", isPresented: .constant(exportError != nil)) {
            Button("Tamam") { exportError = nil }
        } message: { Text(exportError ?? "") }
    }

    private func export(_ make: () throws -> URL) {
        do { shareURL = try make() } catch { exportError = error.localizedDescription }
    }

    private func writeTemp(_ text: String, ext: String) throws -> URL {
        let safe = scan.name.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mekan-\(safe).\(ext)")
        try Data(text.utf8).write(to: url)
        return url
    }

    private var qualityTitle: String {
        switch quality.level {
        case .high: "Tarama güveni: yüksek"
        case .medium: "Tarama güveni: orta"
        case .low: "Tarama güveni: düşük"
        case nil: "Tarama güveni: bilinmiyor"
        }
    }
    private var qualityIcon: String {
        switch quality.level {
        case .high: "checkmark.seal.fill"
        case .medium: "exclamationmark.triangle.fill"
        case .low: "xmark.octagon.fill"
        case nil: "questionmark.circle"
        }
    }
    private var qualityColor: Color {
        switch quality.level {
        case .high: .green
        case .medium: .orange
        case .low: .red
        case nil: .secondary
        }
    }

    private func meters(_ v: Double) -> String { String(format: "%.2f m", v) }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary).monospacedDigit() }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(text) }
    }
}
