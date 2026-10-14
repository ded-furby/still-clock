import Foundation

public enum Dial: String, CaseIterable, Codable, Identifiable {
    case porcelain, parchment, sage, glacier, rose, lavender, cobalt, graphite
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum Movement: String, CaseIterable, Codable, Identifiable {
    case sweep, mechanical, quartz
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var description: String {
        switch self {
        case .sweep: return "A continuous, quiet sweep."
        case .mechanical: return "Eight steps a second. 28,800 beats an hour."
        case .quartz: return "One precise tick every second."
        }
    }
    public func seconds(_ value: Double) -> Double {
        switch self {
        case .sweep: return value
        case .mechanical: return floor(value * 8) / 8
        case .quartz: return floor(value)
        }
    }
    public var frameInterval: Double {
        switch self { case .sweep: return 1 / 30; case .mechanical: return 1 / 8; case .quartz: return 1 }
    }
}

public enum AppearanceMode: String, CaseIterable, Codable, Identifiable {
    case day, night, automatic
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct ClockSettings: Codable, Equatable {
    public var dial: Dial = .parchment
    public var movement: Movement = .sweep
    public var appearance: AppearanceMode = .day
    public var scale: Double = 0.82
    public var showSeconds: Bool = true
    public var showNumerals: Bool = true
    public var showDate: Bool = false
    public var drift: Bool = true
    public var timeZoneID: String = "system"
    public init() {}
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .autoupdatingCurrent }
    public mutating func validate() {
        scale = scale.isFinite ? min(0.94, max(0.45, scale)) : 0.82
        if timeZoneID != "system", TimeZone(identifier: timeZoneID) == nil { timeZoneID = "system" }
    }
    public func isNight(systemDark: Bool) -> Bool {
        appearance == .night || (appearance == .automatic && systemDark)
    }
}

public struct HandAngles: Equatable {
    public let hour: Double
    public let minute: Double
    public let second: Double
    public init(date: Date, timeZone: TimeZone, movement: Movement) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let seconds = movement.seconds(Double(c.second ?? 0) + Double(c.nanosecond ?? 0) / 1_000_000_000)
        let minutes = Double(c.minute ?? 0) + seconds / 60
        hour = (Double((c.hour ?? 0) % 12) + minutes / 60) * .pi / 6
        minute = minutes * .pi / 30
        second = seconds * .pi / 30
    }
}

public enum ClockGeometry {
    // Smooth bounded movement; this reduces static exposure, but cannot guarantee against burn-in.
    public static func drift(at time: TimeInterval, amplitude: Double) -> (x: Double, y: Double) {
        (sin(time / 173) * amplitude, cos(time / 211) * amplitude)
    }
}
