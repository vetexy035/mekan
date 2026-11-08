import SwiftUI
import MekanCore

struct ScanListView: View {
    @EnvironmentObject private var store: ScanStore
    @State private var path = NavigationPath()
    @State private var scanning = false
    @State private var scanningHome = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.scans.isEmpty && store.homes.isEmpty {
                    ContentUnavailableView {
                        Label("Henüz tarama yok", systemImage: "viewfinder")
                    } description: {
                        Text("Odanın ortasında dur, telefonu yavaşça çevirerek duvarları, kapıları ve eşyaları tara. Birden çok odayı tek planda görmek için \"Ev planı\" taramasını seç.")
                    } actions: {
                        scanMenu
                    }
                } else {
                    List {
                        if !store.homes.isEmpty {
                            Section("Ev planları") {
                                ForEach(store.homes) { home in
                                    NavigationLink(value: HomeRoute(id: home.id)) { HomeRow(home: home) }
                                }
                            }
                        }
                        Section(store.homes.isEmpty ? "" : "Odalar") {
                            ForEach(store.scans) { scan in
                                NavigationLink(value: scan.id) { ScanRow(scan: scan) }
                            }
                            .onDelete { idx in idx.map { store.scans[$0].id }.forEach(store.delete) }
                        }
                    }
                }
            }
            .navigationTitle("Mekan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                if !(store.scans.isEmpty && store.homes.isEmpty) {
                    ToolbarItem(placement: .topBarTrailing) { scanMenu }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let scan = store.scan(id) { ScanDetailView(scan: scan) }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                if let home = store.home(route.id) { HomePlanView(home: home) }
            }
            .fullScreenCover(isPresented: $scanning) {
                ScanView { id in path.append(id) }.environmentObject(store)
            }
            .fullScreenCover(isPresented: $scanningHome) {
                HomeScanView { id in path.append(HomeRoute(id: id)) }.environmentObject(store)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    @ViewBuilder private var scanMenu: some View {
        if RoomScanner.isSupported {
            Menu {
                Button { scanning = true } label: { Label("Tek oda", systemImage: "square.dashed") }
                Button { scanningHome = true } label: { Label("Ev planı (çok oda)", systemImage: "house") }
            } label: {
                Label("Yeni tarama", systemImage: "plus.viewfinder")
            }
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

private struct HomeRow: View {
    @EnvironmentObject private var store: ScanStore
    let home: HomePlan
    var body: some View {
        let rooms = store.rooms(of: home)
        VStack(alignment: .leading, spacing: 4) {
            Label(home.name, systemImage: "house.fill").font(.headline)
            Text(String(format: "%d oda · %.1f m²", rooms.count, home.totalArea(rooms: rooms)))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
