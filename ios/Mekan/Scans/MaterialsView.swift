import SwiftUI
import MekanCore

/// Prices and calculation settings, remembered across scans.
enum MaterialSettingsStore {
    static var settings: MaterialEstimate.Settings {
        let d = UserDefaults.standard
        return .init(paintCoats: d.object(forKey: "mat.coats") as? Double ?? 2,
                     paintCoverage: d.object(forKey: "mat.coverage") as? Double ?? 10,
                     floorWaste: d.object(forKey: "mat.waste") as? Double ?? 0.10)
    }
    static var prices: MaterialPrices {
        let d = UserDefaults.standard
        return MaterialPrices(paintPerLiter: d.double(forKey: "price.paint"),
                              floorPerSquareMeter: d.double(forKey: "price.floor"),
                              skirtingPerPiece: d.double(forKey: "price.skirting"),
                              wallpaperPerRoll: d.double(forKey: "price.wallpaper"),
                              curtainPerMeter: d.double(forKey: "price.curtain"))
    }
}

struct MaterialsView: View {
    let scan: RoomScan
    init(scan: RoomScan) { self.scan = scan }

    @AppStorage("mat.coats") private var coats = 2.0
    @AppStorage("mat.coverage") private var coverage = 10.0
    @AppStorage("mat.waste") private var waste = 0.10
    @AppStorage("price.paint") private var paintPrice = 0.0
    @AppStorage("price.floor") private var floorPrice = 0.0
    @AppStorage("price.skirting") private var skirtingPrice = 0.0
    @AppStorage("price.wallpaper") private var wallpaperPrice = 0.0
    @AppStorage("price.curtain") private var curtainPrice = 0.0

    private var estimate: MaterialEstimate {
        MaterialEstimate(scan: scan, settings: .init(paintCoats: coats, paintCoverage: coverage, floorWaste: waste))
    }
    private var cost: MaterialCost {
        estimate.cost(MaterialPrices(paintPerLiter: paintPrice, floorPerSquareMeter: floorPrice,
                                     skirtingPerPiece: skirtingPrice, wallpaperPerRoll: wallpaperPrice,
                                     curtainPerMeter: curtainPrice))
    }

    var body: some View {
        let e = estimate, c = cost
        Form {
            Section {
                item("Boya", detail: String(format: "%.1f m² duvar · %.1f L", e.netWallArea, e.paintLiters),
                     buy: MaterialText.cans(e.paintCans), price: $paintPrice, unit: "TL/L", cost: c.paint)
                item("Parke / zemin", detail: String(format: "%%%.0f fire dahil", waste * 100),
                     buy: String(format: "%.1f m²", e.floorAreaWithWaste), price: $floorPrice, unit: "TL/m²", cost: c.floor)
                item("Süpürgelik", detail: String(format: "%.1f m (kapı boşlukları hariç)", e.skirtingMeters),
                     buy: "\(e.skirtingPieces) adet × 2,4 m", price: $skirtingPrice, unit: "TL/adet", cost: c.skirting)
                item("Duvar kâğıdı", detail: "53 cm × 10 m rulo",
                     buy: "\(e.wallpaperRolls) rulo", price: $wallpaperPrice, unit: "TL/rulo", cost: c.wallpaper)
                item("Perde kumaşı", detail: "pencere genişliğinin 2 katı",
                     buy: String(format: "%.1f m", e.curtainFabricMeters), price: $curtainPrice, unit: "TL/m", cost: c.curtain)
            } header: {
                Text("Alınacaklar")
            } footer: {
                Text("Fiyat girdiğin kalemler toplama eklenir. Fiyatlar bir sonraki odada da hatırlanır.")
            }

            if c.total > 0 {
                Section {
                    HStack {
                        Text("Toplam bütçe").font(.headline)
                        Spacer()
                        Text(MaterialText.tl(c.total)).font(.headline).monospacedDigit()
                    }
                }
            }

            Section("Hesap ayarları") {
                Stepper(value: $coats, in: 1...4, step: 1) { Text("Boya katı: \(Int(coats))") }
                Stepper(value: $coverage, in: 5...16, step: 1) { Text("1 L boya \(Int(coverage)) m² örter (tek kat)") }
                Stepper(value: $waste, in: 0...0.2, step: 0.05) { Text(String(format: "Zemin firesi: %%%.0f", waste * 100)) }
            }
        }
        .navigationTitle("Malzeme hesabı")
    }

    private func item(_ title: String, detail: String, buy: String,
                      price: Binding<Double>, unit: String, cost: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                Text(buy).font(.headline).monospacedDigit()
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Fiyat", value: price, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 110)
                    .textFieldStyle(.roundedBorder)
                Text(unit).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if cost > 0 { Text(MaterialText.tl(cost)).monospacedDigit().foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Shared Turkish formatting for the screen and the PDF.
enum MaterialText {
    static func cans(_ cans: [Double: Int]) -> String {
        guard !cans.isEmpty else { return "—" }
        return cans.sorted { $0.key > $1.key }
            .map { size, n in "\(n) × \(liters(size)) L" }
            .joined(separator: " + ")
    }

    static func liters(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }

    static func tl(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "tr_TR")
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: v)) ?? "\(Int(v))") + " TL"
    }
}
