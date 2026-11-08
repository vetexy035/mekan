import SwiftUI
import UIKit
import MekanCore

/// One A4 page: floor plan with wall lengths, measurements and the material list.
/// Meant to be sent to a tradesperson or family over WhatsApp/Mail.
@MainActor
enum PlanPDF {
    static func make(scan: RoomScan) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 in points
        let margin: CGFloat = 40
        let width = page.width - 2 * margin
        let m = RoomMeasurements(scan: scan)
        let e = MaterialEstimate(scan: scan, settings: MaterialSettingsStore.settings)
        let cost = e.cost(MaterialSettingsStore.prices)

        let safeName = scan.name.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Mekan-\(safeName).pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: page, format: {
            let f = UIGraphicsPDFRendererFormat()
            f.documentInfo = [kCGPDFContextTitle as String: "\(scan.name) – oda planı",
                              kCGPDFContextCreator as String: "Mekan"]
            return f
        }())

        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            var y = margin

            // Header
            draw("\(scan.name) – oda planı", at: &y, x: margin, width: width, font: .boldSystemFont(ofSize: 20))
            let date = scan.capturedAt.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR")))
            draw("Tarama: \(date) · Mekan ile LiDAR taraması", at: &y, x: margin, width: width,
                 font: .systemFont(ofSize: 10), color: .darkGray)
            y += 8

            // Plan (drawn as vectors, so it stays sharp when zoomed)
            let planHeight: CGFloat = 360
            let plan = ImageRenderer(content: FloorPlanView(scan: scan)
                .frame(width: width, height: planHeight)
                .environment(\.colorScheme, .light))
            plan.render { _, drawPlan in
                let g = ctx.cgContext
                g.saveGState()
                g.translateBy(x: margin, y: y)
                drawPlan(g)
                g.restoreGState()
            }
            UIColor(white: 0.85, alpha: 1).setStroke()
            UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: width, height: planHeight), cornerRadius: 6).stroke()
            y += planHeight + 6
            draw("Turuncu: kapı · Mavi: pencere · Mavi alanlar: eşyalar", at: &y, x: margin, width: width,
                 font: .systemFont(ofSize: 9), color: .gray)
            y += 10

            // Measurements | Materials, side by side
            let colW = (width - 20) / 2
            var left = y, right = y
            draw("Ölçüler", at: &left, x: margin, width: colW, font: .boldSystemFont(ofSize: 13))
            let area = String(format: "%.1f m²", m.floorArea) + (m.isAreaEstimated ? " (yaklaşık)" : "")
            for (k, v) in [("Boy", meters(m.length)), ("En", meters(m.width)), ("Tavan", meters(m.ceilingHeight)),
                           ("Zemin alanı", area), ("Çevre", meters(m.perimeter)),
                           ("Boyanacak duvar", String(format: "%.1f m²", e.netWallArea)),
                           ("Kapı / pencere", "\(m.doorCount) / \(m.windowCount)")] {
                row(k, v, at: &left, x: margin, width: colW)
            }

            draw("Malzeme listesi", at: &right, x: margin + colW + 20, width: colW, font: .boldSystemFont(ofSize: 13))
            let p = MaterialSettingsStore.prices
            let rows: [(String, String, Double, Double)] = [
                ("Boya", MaterialText.cans(e.paintCans), p.paintPerLiter, cost.paint),
                ("Parke / zemin", String(format: "%.1f m²", e.floorAreaWithWaste), p.floorPerSquareMeter, cost.floor),
                ("Süpürgelik", "\(e.skirtingPieces) × 2,4 m", p.skirtingPerPiece, cost.skirting),
                ("Duvar kâğıdı", "\(e.wallpaperRolls) rulo", p.wallpaperPerRoll, cost.wallpaper),
                ("Perde kumaşı", String(format: "%.1f m", e.curtainFabricMeters), p.curtainPerMeter, cost.curtain),
            ]
            for (k, v, price, c) in rows {
                row(k, price > 0 ? "\(v) · \(MaterialText.tl(c))" : v, at: &right, x: margin + colW + 20, width: colW)
            }
            if cost.total > 0 {
                right += 4
                row("Toplam", MaterialText.tl(cost.total), at: &right, x: margin + colW + 20, width: colW, bold: true)
            }

            // Footer
            var fy = page.height - margin - 24
            draw("Ölçüler telefonun LiDAR taramasından alınmıştır; birkaç cm sapma olabilir. Kesim öncesi kritik ölçüleri metreyle doğrulayın.",
                 at: &fy, x: margin, width: width, font: .systemFont(ofSize: 8), color: .gray)
        }
        return url
    }

    private static func meters(_ v: Double) -> String { String(format: "%.2f m", v).replacingOccurrences(of: ".", with: ",") }

    private static func draw(_ text: String, at y: inout CGFloat, x: CGFloat, width: CGFloat,
                             font: UIFont, color: UIColor = .black) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let s = NSAttributedString(string: text, attributes: attrs)
        let h = ceil(s.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin], context: nil).height)
        s.draw(with: CGRect(x: x, y: y, width: width, height: h), options: [.usesLineFragmentOrigin], context: nil)
        y += h + 4
    }

    private static func row(_ key: String, _ value: String, at y: inout CGFloat, x: CGFloat, width: CGFloat, bold: Bool = false) {
        let font: UIFont = bold ? .boldSystemFont(ofSize: 11) : .systemFont(ofSize: 11)
        NSAttributedString(string: key, attributes: [.font: font, .foregroundColor: UIColor.darkGray])
            .draw(at: CGPoint(x: x, y: y))
        let v = NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: UIColor.black])
        v.draw(at: CGPoint(x: x + width - v.size().width, y: y))
        UIColor(white: 0.9, alpha: 1).setFill()
        UIRectFill(CGRect(x: x, y: y + 16, width: width, height: 0.5))
        y += 20
    }
}
