import AppKit

public struct ClockDisplay: Identifiable {
    public let id: String
    public let name: String
    public init(screen: NSScreen) {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        if let number, let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() {
            id = CFUUIDCreateString(nil, uuid) as String
        } else { id = screen.localizedName }
        name = screen.localizedName
    }
}

public extension ClockSettings {
    func layout(for screen: NSScreen?) -> DisplayLayout {
        guard let screen else { return .centered }
        return displayLayouts?[ClockDisplay(screen: screen).id] ?? .centered
    }
}

public struct DialPlacement {
    public let center: CGPoint
    public let diameter: CGFloat
    public init(size: CGSize, scale: Double, layout: DisplayLayout) {
        let companion = layout == .flowRight && size.width >= size.height * 1.2
        diameter = companion ? min(size.height * scale, size.width * 0.47) : min(size.width, size.height) * scale
        center = CGPoint(x: companion ? size.width * 0.94 - diameter / 2 : size.width / 2, y: size.height / 2)
    }
}
