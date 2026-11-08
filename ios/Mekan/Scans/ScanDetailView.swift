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

    private var m: RoomMeasurements { RoomMeasurements(scan: scan) }

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
            }

            Section("Ölçüler") {
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
                        row(FurnitureNames.turkish(o.category), String(format: "%.0f × %.0f × %.0f cm", o.size.x * 100, o.size.z * 100, o.size.y * 100))
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
                ShareLink(item: store.modelURL(scan.id)) {
                    Label("USDZ paylaş", systemImage: "square.and.arrow.up")
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
            Room3DView(scan: scan)
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
