import AppKit

@main struct Artwork {
    @MainActor static func main() throws {
        let out = URL(fileURLWithPath: "Resources")
        try FileManager.default.createDirectory(at: out.appendingPathComponent("AppIcon.iconset"), withIntermediateDirectories: true)
        let renderer = ClockRenderer()
        let date = ISO8601DateFormatter().date(from: "2026-10-14T10:08:36Z")!
        var settings = ClockSettings(); settings.scale = 0.87; settings.timeZoneID = "GMT"
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                let inset = CGFloat(pixels) * 0.04
                let rect = CGRect(x: inset, y: inset, width: CGFloat(pixels) - 2 * inset, height: CGFloat(pixels) - 2 * inset)
                c.addPath(CGPath(roundedRect: rect, cornerWidth: CGFloat(pixels) * 0.21, cornerHeight: CGFloat(pixels) * 0.21, transform: nil)); c.clip()
                renderer.draw(in: c, size: CGSize(width: pixels, height: pixels), date: date, settings: settings, backingScale: 1)
                let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
                let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
                try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("AppIcon.iconset/\(name)"))
            }
        }
        let rep = renderer.image(size: CGSize(width: 600, height: 375), date: date, settings: settings)!
        try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("thumbnail.png"))
    }
}
