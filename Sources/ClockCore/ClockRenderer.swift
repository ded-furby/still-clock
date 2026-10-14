import AppKit

public extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

public struct DialPalette {
    public let background: NSColor
    public let ink: NSColor
    public let subtle: NSColor
    public let lume: NSColor
    public let second: NSColor
    public static func make(_ dial: Dial, night: Bool) -> DialPalette {
        if night {
            return DialPalette(background: NSColor(hex: 0x11171A), ink: NSColor(hex: 0x90B9AB),
                               subtle: NSColor(hex: 0x46625C), lume: NSColor(hex: 0xB8F4DD), second: NSColor(hex: 0xD6AC7C))
        }
        let background: UInt32
        switch dial {
        case .porcelain: background = 0xECEEEB
        case .parchment: background = 0xE4DDCF
        case .sage: background = 0xC3CDBD
        case .glacier: background = 0xCADBDF
        case .rose: background = 0xE4C9C1
        case .lavender: background = 0xD1D0E5
        case .cobalt: background = 0x284F85
        case .graphite: background = 0x343B3D
        }
        let dark = dial == .cobalt || dial == .graphite
        return DialPalette(background: NSColor(hex: background),
                           ink: NSColor(hex: dark ? 0xE5E8E5 : 0x3B4544),
                           subtle: NSColor(hex: dark ? 0xA3B4C4 : 0x7C827C),
                           lume: NSColor(hex: 0xF9FAEF),
                           second: NSColor(hex: dark ? 0xDCAE87 : 0xA65E46))
    }
}

/// The app, preview, screen saver, and exported stills use this single renderer.
/// A cached vector dial keeps the expensive shadows/type out of the animation loop.
@MainActor public final class ClockRenderer {
    private var cachedDial: CGImage?
    private var cacheKey = ""
    public init() {}

    public func draw(in context: CGContext, size: CGSize, date: Date = Date(),
                     settings: ClockSettings, backingScale: CGFloat = 2,
                     systemDark: Bool = false, allowDrift: Bool = false) {
        guard size.width > 0, size.height > 0 else { return }
        let night = settings.isNight(systemDark: systemDark)
        let p = DialPalette.make(settings.dial, night: night)
        context.saveGState()
        context.setFillColor(p.background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        // A soft wash of light gives the flat dial a tactile, paper-like surface.
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            NSColor.white.withAlphaComponent(night ? 0.025 : 0.11).cgColor,
            NSColor.black.withAlphaComponent(night ? 0.11 : 0.035).cgColor
        ] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height),
                                       end: CGPoint(x: size.width, y: 0), options: [])
        }
        let d = min(size.width, size.height) * settings.scale
        let drift = allowDrift && settings.drift ? ClockGeometry.drift(at: date.timeIntervalSince1970,
                                                                       amplitude: min(size.width, size.height) * 0.012) : (x: 0.0, y: 0.0)
        context.translateBy(x: size.width / 2 + drift.x, y: size.height / 2 + drift.y)
        context.scaleBy(x: d / 1000, y: d / 1000)
        let pixels = min(3072, max(256, Int((d * backingScale).rounded(.up))))
        let key = "\(pixels)-\(settings.dial.rawValue)-\(night)-\(settings.showNumerals)"
        if key != cacheKey {
            cacheKey = key
            cachedDial = makeDial(pixels: pixels, palette: p, night: night, numerals: settings.showNumerals)
        }
        if let cachedDial { context.draw(cachedDial, in: CGRect(x: -500, y: -500, width: 1000, height: 1000)) }
        if settings.showDate {
            let formatter = DateFormatter()
            formatter.timeZone = settings.timeZone
            formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
            text(formatter.string(from: date).uppercased(), at: CGPoint(x: 0, y: -182), size: 13,
                 color: p.subtle, context: context, tracking: 2)
        }
        let a = HandAngles(date: date, timeZone: settings.timeZone, movement: settings.movement)
        hand(context, angle: a.hour, length: 258, tail: 54, width: 15, palette: p, night: night)
        hand(context, angle: a.minute, length: 373, tail: 72, width: 10, palette: p, night: night)
        if settings.showSeconds {
            context.saveGState()
            context.rotate(by: -a.second)
            context.setShadow(offset: CGSize(width: 3, height: -5), blur: 4,
                              color: NSColor.black.withAlphaComponent(0.18).cgColor)
            context.setStrokeColor(p.second.cgColor)
            context.setLineWidth(2.1)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: 0, y: -87)); context.addLine(to: CGPoint(x: 0, y: 404)); context.strokePath()
            context.setFillColor(p.second.cgColor)
            context.fillEllipse(in: CGRect(x: -5, y: -78, width: 10, height: 10))
            context.restoreGState()
        }
        context.setShadow(offset: CGSize(width: 2, height: -3), blur: 5, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        context.setFillColor((night ? NSColor(hex: 0x384B47) : NSColor(hex: 0xD7D9D2)).cgColor)
        context.fillEllipse(in: CGRect(x: -16, y: -16, width: 32, height: 32))
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setFillColor(p.lume.cgColor)
        context.fillEllipse(in: CGRect(x: -12, y: -12, width: 24, height: 24))
        context.setFillColor(p.second.cgColor)
        context.fillEllipse(in: CGRect(x: -3, y: -3, width: 6, height: 6))
        context.restoreGState()
    }

    private func makeDial(pixels: Int, palette p: DialPalette, night: Bool, numerals: Bool) -> CGImage? {
        guard let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.scaleBy(x: CGFloat(pixels) / 1000, y: CGFloat(pixels) / 1000)
        c.translateBy(x: 500, y: 500)
        for tick in 0..<60 {
            let angle = Double(tick) * .pi / 30
            c.saveGState(); c.rotate(by: -angle)
            if tick % 5 == 0 {
                let rect = CGRect(x: -5, y: 367, width: 10, height: 60)
                c.setShadow(offset: CGSize(width: 3, height: -4), blur: 4,
                            color: NSColor.black.withAlphaComponent(night ? 0.4 : 0.24).cgColor)
                c.setFillColor((night ? NSColor(hex: 0x34453F) : NSColor(hex: 0xAFB5AF)).cgColor)
                c.addPath(CGPath(roundedRect: rect, cornerWidth: 4.5, cornerHeight: 4.5, transform: nil)); c.fillPath()
                c.setShadow(offset: .zero, blur: night ? 7 : 0,
                            color: night ? p.lume.withAlphaComponent(0.35).cgColor : nil)
                c.setFillColor(p.lume.cgColor)
                c.addPath(CGPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)); c.fillPath()
                c.setShadow(offset: .zero, blur: 0, color: nil)
            } else {
                c.setStrokeColor(p.subtle.withAlphaComponent(night ? 0.65 : 0.86).cgColor)
                c.setLineWidth(1.65); c.setLineCap(.round)
                c.move(to: CGPoint(x: 0, y: 402)); c.addLine(to: CGPoint(x: 0, y: 425)); c.strokePath()
            }
            c.restoreGState()
        }
        if numerals {
            for hour in 1...12 {
                let angle = Double(hour) * .pi / 6
                text(String(hour), at: CGPoint(x: sin(angle) * 297, y: cos(angle) * 297),
                     size: 57, color: p.ink, context: c)
            }
            for minute in stride(from: 0, to: 60, by: 5) {
                let angle = Double(minute) * .pi / 30
                c.saveGState(); c.translateBy(x: sin(angle) * 468, y: cos(angle) * 468)
                var rotation = -angle
                if minute > 15 && minute < 45 { rotation += .pi }
                c.rotate(by: rotation)
                text(minute == 0 ? "60" : String(format: "%02d", minute), at: .zero,
                     size: 22, color: p.subtle, context: c)
                c.restoreGState()
            }
        }
        return c.makeImage()
    }

    private func hand(_ c: CGContext, angle: Double, length: CGFloat, tail: CGFloat,
                      width: CGFloat, palette p: DialPalette, night: Bool) {
        c.saveGState(); c.rotate(by: -angle)
        c.setShadow(offset: CGSize(width: 5, height: -7), blur: 6, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: -tail))
        path.addLine(to: CGPoint(x: -width / 2, y: length - 9))
        path.addLine(to: CGPoint(x: 0, y: length))
        path.addLine(to: CGPoint(x: width / 2, y: length - 9))
        path.addLine(to: CGPoint(x: width / 2, y: -tail)); path.closeSubpath()
        c.addPath(path); c.setFillColor((night ? NSColor(hex: 0x526860) : NSColor(hex: 0xB0B7B0)).cgColor); c.fillPath()
        c.setShadow(offset: .zero, blur: night ? 9 : 0, color: night ? p.lume.withAlphaComponent(0.3).cgColor : nil)
        c.setStrokeColor(p.lume.cgColor); c.setLineWidth(width * 0.48); c.setLineCap(.round)
        c.move(to: CGPoint(x: 0, y: 28)); c.addLine(to: CGPoint(x: 0, y: length - 13)); c.strokePath()
        c.setShadow(offset: .zero, blur: 0, color: nil)
        c.setStrokeColor(NSColor.white.withAlphaComponent(night ? 0.15 : 0.8).cgColor); c.setLineWidth(1)
        c.move(to: CGPoint(x: -width / 2 + 1, y: -tail + 1)); c.addLine(to: CGPoint(x: -width / 2 + 1, y: length - 10)); c.strokePath()
        c.restoreGState()
    }

    private func text(_ value: String, at point: CGPoint, size: CGFloat, color: NSColor,
                      context: CGContext, tracking: CGFloat = 0) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let font = NSFont(name: "AvenirNext-Regular", size: size) ?? NSFont.systemFont(ofSize: size, weight: .light)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: tracking]
        let string = NSAttributedString(string: value, attributes: attributes)
        let dimensions = string.size()
        string.draw(at: CGPoint(x: point.x - dimensions.width / 2, y: point.y - dimensions.height / 2))
        NSGraphicsContext.restoreGraphicsState()
    }

    public func image(size: CGSize, date: Date, settings: ClockSettings) -> NSBitmapImageRep? {
        guard let c = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        draw(in: c, size: size, date: date, settings: settings, backingScale: 1)
        guard let image = c.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image)
    }
}
