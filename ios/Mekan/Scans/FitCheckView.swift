import SwiftUI
import MekanCore

/// "Sığar mı?": enter the outer size of a piece you want to buy and see whether it
/// gets through the door, fits under the ceiling and where along the walls it can stand.
struct FitCheckView: View {
    let scan: RoomScan
    init(scan: RoomScan) { self.scan = scan }

    @State private var width: Double?
    @State private var depth: Double?
    @State private var height: Double?
    @FocusState private var focused: Bool

    private var item: FurnitureSize? {
        guard let w = width, let d = depth, let h = height, w > 0, d > 0, h > 0 else { return nil }
        return FurnitureSize(width: w / 100, depth: d / 100, height: h / 100)
    }

    var body: some View {
        let report = item.map { FitCheck.check($0, in: scan) }
        Form {
            Section {
                field("Genişlik", $width)
                field("Derinlik", $depth)
                field("Yükseklik", $height)
            } header: {
                Text("Almak istediğin eşyanın dış ölçüleri")
            } footer: {
                Text("Ürün sayfasındaki G × D × Y ölçülerini santimetre olarak gir.")
            }

            if let report, let item {
                Section("Sonuç") {
                    result(report.door.map(doorText) ?? ("Kapı algılanmadı", "questionmark.circle", .secondary))
                    result(report.fitsUnderCeiling
                           ? ("Tavana sığar", "checkmark.circle.fill", .green)
                           : ("Tavandan yüksek!", "xmark.octagon.fill", .red))
                    if report.spots.isEmpty {
                        result(("Hiçbir duvarda \(cm(item.width)) boş yer yok", "xmark.octagon.fill", .red))
                    } else {
                        result(("\(report.spots.count) yerde sığar (planda yeşil)", "checkmark.circle.fill", .green))
                    }
                }

                Section {
                    FloorPlanView(scan: scan, highlights: report.spots)
                        .frame(height: 280)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    ForEach(Array(report.spots.enumerated()), id: \.offset) { _, spot in
                        HStack {
                            Text("Boş duvar: \(cm(spot.freeLength))")
                            Spacer()
                            if !spot.leavesWalkway {
                                Label("Yürüme yolu dar", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                } header: {
                    Text("Yerleşebileceği duvarlar")
                } footer: {
                    Text("Kapılar (±10 cm), eşyadan yüksekse pencereler ve duvara dayalı mevcut eşyalar çıkarıldı. Önünde en az 60 cm yürüme yolu hedeflenir.")
                }
            }
        }
        .navigationTitle("Sığar mı?")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Tamam") { focused = false }
            }
        }
    }

    private func field(_ title: String, _ value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("cm", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .focused($focused)
            Text("cm").foregroundStyle(.secondary)
        }
    }

    private func doorText(_ p: DoorPassage) -> (String, String, Color) {
        switch p {
        case .straight: ("Kapıdan rahat geçer", "checkmark.circle.fill", .green)
        case .tilted: ("Kapıdan ancak eğerek geçer", "exclamationmark.triangle.fill", .orange)
        case .no: ("Kapıdan geçmez!", "xmark.octagon.fill", .red)
        }
    }

    private func result(_ r: (String, String, Color)) -> some View {
        Label { Text(r.0) } icon: { Image(systemName: r.1).foregroundStyle(r.2) }
    }

    private func cm(_ meters: Double) -> String { "\(Int((meters * 100).rounded())) cm" }
}
