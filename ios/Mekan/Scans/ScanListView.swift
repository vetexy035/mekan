import SwiftUI
import MekanCore

struct ScanListView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var path: [UUID] = []
    @State private var scanning = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.scans.isEmpty {
                    ContentUnavailableView {
                        Label("Henüz tarama yok", systemImage: "viewfinder")
                    } description: {
                        Text("Odanın ortasında dur, telefonu yavaşça çevirerek duvarları, kapıları ve eşyaları tara.")
                    } actions: {
                        scanButton
                    }
                } else {
                    List {
                        ForEach(store.scans) { scan in
                            NavigationLink(value: scan.id) { ScanRow(scan: scan) }
                        }
                        .onDelete { idx in idx.map { store.scans[$0].id }.forEach(store.delete) }
                    }
                }
            }
            .navigationTitle("Mekan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                if !store.scans.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { scanButton }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let scan = store.scan(id) { ScanDetailView(scan: scan) }
            }
            .fullScreenCover(isPresented: $scanning) {
                ScanView { id in path.append(id) }.environmentObject(store)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    @ViewBuilder private var scanButton: some View {
        if RoomScanner.isSupported {
            Button { scanning = true } label: { Label("Yeni tarama", systemImage: "plus.viewfinder") }
                .buttonStyle(.borderedProminent)
        } else {
            Text("Bu cihazda LiDAR yok. Tarama için iPhone 12 Pro veya sonrası bir Pro model gerekir.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
}

private struct ScanRow: View {
    let scan: RoomScan
    var body: some View {
        let m = RoomMeasurements(scan: scan)
        VStack(alignment: .leading, spacing: 4) {
            Text(scan.name).font(.headline)
            Text(String(format: "%.1f × %.1f m · %.1f m²", m.length, m.width, m.floorArea))
                .font(.subheadline).foregroundStyle(.secondary)
            Text(scan.capturedAt, style: .date).font(.caption).foregroundStyle(.tertiary)
        }
    }
}
