import UIKit

/// Procedurally painted textures (no downloaded assets, no licenses).
/// Deterministic: the same kind + color always gives the same image, and results are cached.
enum TextureFactory {
    enum Kind: String { case wood, fabric, parquet, wall, stone }

    private static var cache: [String: UIImage] = [:]

    static func image(_ kind: Kind, color: UIColor) -> UIImage {
        let key = "\(kind.rawValue)-\(color.description)"
        if let hit = cache[key] { return hit }
        let img: UIImage
        switch kind {
        case .wood: img = wood(color)
        case .fabric: img = fabric(color)
        case .parquet: img = parquet(color)
        case .wall: img = noise(color, amount: 0.035, size: 256)
        case .stone: img = noise(color, amount: 0.12, size: 256)
        }
        cache[key] = img
        return img
    }

    /// Equirectangular sky used as image-based lighting: bright warm top, neutral middle, darker floor.
    static func environment() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1).cgColor,
                          UIColor(white: 0.85, alpha: 1).cgColor,
                          UIColor(red: 0.45, green: 0.38, blue: 0.32, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
                                      locations: [0, 0.5, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    // MARK: Painters

    private static func wood(_ base: UIColor) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        var rng = SeededRandom(seed: 7)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let g = ctx.cgContext
            base.setFill(); g.fill(CGRect(origin: .zero, size: size))
            // Long, slightly wavy grain lines.
            for _ in 0..<140 {
                let y = rng.next() * size.height
                let amp = 2 + rng.next() * 6, freq = 0.005 + rng.next() * 0.02
                let phase = rng.next() * .pi * 2
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: y))
                stride(from: 0, through: size.width, by: 8).forEach { x in
                    path.addLine(to: CGPoint(x: x, y: y + sin(x * freq + phase) * amp))
                }
                let dark = rng.next() < 0.7
                (dark ? UIColor.black : UIColor.white).withAlphaComponent(0.04 + rng.next() * 0.08).setStroke()
                path.lineWidth = 0.6 + rng.next() * 2.2
                path.stroke()
            }
        }
    }

    private static func fabric(_ base: UIColor) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        var rng = SeededRandom(seed: 11)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let g = ctx.cgContext
            base.setFill(); g.fill(CGRect(origin: .zero, size: size))
            // Woven look: alternating fine threads in both directions.
            for i in stride(from: 0, to: 256, by: 2) {
                let a = 0.03 + rng.next() * 0.05
                UIColor.black.withAlphaComponent(a).setFill()
                g.fill(CGRect(x: 0, y: CGFloat(i), width: size.width, height: 1))
                UIColor.white.withAlphaComponent(a * 0.8).setFill()
                g.fill(CGRect(x: CGFloat(i), y: 0, width: 1, height: size.height))
            }
            sprinkle(g, size: size, rng: &rng, count: 1500, alpha: 0.05)
        }
    }

    /// 1 m × 1 m of oak planks (14 cm wide, staggered joints).
    private static func parquet(_ base: UIColor) -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        let plankW = size.width * 0.14, plankL = size.height * 0.6
        var rng = SeededRandom(seed: 3)
        let grain = wood(base)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let g = ctx.cgContext
            var x: CGFloat = 0
            while x < size.width {
                var y = -rng.next() * plankL
                while y < size.height {
                    let rect = CGRect(x: x, y: y, width: plankW, height: plankL)
                    // Grain runs along the plank: draw the wood texture rotated 90°.
                    g.saveGState()
                    g.clip(to: rect)
                    g.translateBy(x: rect.midX, y: rect.midY)
                    g.rotate(by: .pi / 2)
                    grain.draw(in: CGRect(x: -plankL / 2, y: -plankW / 2 - rng.next() * 200, width: plankL, height: 512))
                    g.restoreGState()
                    // Per-plank tone variation and a thin dark seam.
                    UIColor(white: rng.next() < 0.5 ? 0 : 1, alpha: 0.03 + rng.next() * 0.06).setFill()
                    g.fill(rect)
                    UIColor.black.withAlphaComponent(0.35).setStroke()
                    g.setLineWidth(1.5)
                    g.stroke(rect)
                    y += plankL
                }
                x += plankW
            }
        }
    }

    private static func noise(_ base: UIColor, amount: CGFloat, size s: CGFloat) -> UIImage {
        let size = CGSize(width: s, height: s)
        var rng = SeededRandom(seed: 5)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            base.setFill(); ctx.cgContext.fill(CGRect(origin: .zero, size: size))
            sprinkle(ctx.cgContext, size: size, rng: &rng, count: Int(s * s / 6), alpha: amount)
        }
    }

    private static func sprinkle(_ g: CGContext, size: CGSize, rng: inout SeededRandom, count: Int, alpha: CGFloat) {
        for _ in 0..<count {
            let p = CGRect(x: rng.next() * size.width, y: rng.next() * size.height, width: 1.5, height: 1.5)
            (rng.next() < 0.5 ? UIColor.black : UIColor.white).withAlphaComponent(alpha * rng.next() * 2).setFill()
            g.fill(p)
        }
    }
}

/// Tiny deterministic RNG so textures look the same every launch.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
}
