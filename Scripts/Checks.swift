import AppKit

/// A dependency-free runner so Command Line Tools users can validate without XCTest or Xcode.
@main struct Checks {
    @MainActor static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }; count += 1
        }
        func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000001 }
        func date(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }
        let utc = TimeZone(secondsFromGMT: 0)!
        for hour in ["00", "12"] {
            let a = HandAngles(date: date("2026-10-14T\(hour):00:00Z"), timeZone: utc, movement: .sweep)
            check(near(a.hour, 0) && near(a.minute, 0) && near(a.second, 0), "midnight/noon")
        }
        let half = HandAngles(date: date("2026-10-14T03:30:00Z"), timeZone: utc, movement: .quartz)
        check(near(half.hour, 3.5 * .pi / 6) && near(half.minute, .pi), "hour hand interpolation")
        check(Movement.quartz.seconds(17.92) == 17, "quartz cadence")
        check(Movement.mechanical.seconds(17.92) == 17.875, "mechanical cadence")
        check(Movement.sweep.seconds(17.92) == 17.92, "continuous movement")
        check(3600 / Movement.mechanical.frameInterval == 28800, "mechanical beat rate")
        let india = HandAngles(date: date("2026-10-14T00:00:00Z"), timeZone: TimeZone(identifier: "Asia/Kolkata")!, movement: .quartz)
        check(near(india.hour, 5.5 * .pi / 6), "fractional time zones")
        let zone = TimeZone(identifier: "Australia/Sydney")!
        let before = HandAngles(date: date("2026-10-03T15:59:00Z"), timeZone: zone, movement: .quartz)
        let after = HandAngles(date: date("2026-10-03T16:00:00Z"), timeZone: zone, movement: .quartz)
        check(near(before.hour, (1 + 59.0 / 60) * .pi / 6) && near(after.hour, .pi / 2), "Sydney DST jumps from 01:59 to 03:00")
        var s = ClockSettings(); s.scale = .infinity; s.timeZoneID = "Invalid/Nowhere"; s.validate()
        check(s.scale == 0.82 && s.timeZoneID == "system", "invalid settings fallback")
        s.scale = -1; s.validate(); check(s.scale == 0.45, "minimum scale")
        s.scale = 4; s.validate(); check(s.scale == 0.94, "maximum scale")
        s.appearance = .automatic
        check(s.isNight(systemDark: true) && !s.isNight(systemDark: false), "automatic light")
        let decoded = try JSONDecoder().decode(ClockSettings.self, from: JSONEncoder().encode(s))
        check(decoded == s, "settings round trip")
        let testDomain = "com.dedfurby.StillClock.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: testDomain)!
        defer { defaults.removePersistentDomain(forName: testDomain) }
        defaults.set(Data("corrupt settings".utf8), forKey: "settingsV1")
        let store = SettingsStore(defaults: defaults)
        check(store.settings == ClockSettings(), "corrupt preferences recover")
        store.settings.dial = .glacier
        check(SettingsStore(defaults: defaults).settings.dial == .glacier, "settings persist across instances")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("StillClock-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let sharedFile = folder.appendingPathComponent("settings.json")
        let writer = SettingsStore(defaults: defaults, sharedSettingsURL: sharedFile)
        writer.settings.dial = .sage
        writer.settings.appearance = .night
        check(writer.syncMessage.isEmpty, "repeated shared preference writes succeed")
        let secondDomain = testDomain + ".isolatedHost"
        let secondDefaults = UserDefaults(suiteName: secondDomain)!
        defer { secondDefaults.removePersistentDomain(forName: secondDomain) }
        let reader = SettingsStore(defaults: secondDefaults, sharedSettingsURL: sharedFile)
        check(reader.settings.dial == .sage && reader.settings.appearance == .night, "isolated defaults hosts share visual settings")
        reader.settings.dial = .rose; writer.reload()
        check(writer.settings.dial == .rose, "cross-host changes reload")
        for t in stride(from: 0.0, through: 86400, by: 123) {
            let a = ClockGeometry.drift(at: t, amplitude: 12)
            let b = ClockGeometry.drift(at: t + 1 / 30, amplitude: 12)
            check(abs(a.x) <= 12 && abs(a.y) <= 12, "bounded pixel shift")
            check(abs(b.x - a.x) < 0.003 && abs(b.y - a.y) < 0.003, "continuous pixel shift")
        }
        let renderer = ClockRenderer()
        let moment = date("2026-10-14T10:08:36Z")
        for dial in Dial.allCases {
            for night in [false, true] {
                s = ClockSettings(); s.dial = dial; s.appearance = night ? .night : .day
                for size in [CGSize(width: 160, height: 100), CGSize(width: 1440, height: 900)] {
                    let image = renderer.image(size: size, date: moment, settings: s)
                    check(image?.pixelsWide == Int(size.width) && image?.pixelsHigh == Int(size.height), "render \(dial) at \(size)")
                    check(image?.representation(using: .png, properties: [:]) != nil, "PNG output")
                }
            }
        }
        s = ClockSettings(); s.timeZoneID = "GMT"
        let first = renderer.image(size: CGSize(width: 400, height: 400), date: moment, settings: s)?.representation(using: .png, properties: [:])
        let second = renderer.image(size: CGSize(width: 400, height: 400), date: moment.addingTimeInterval(5), settings: s)?.representation(using: .png, properties: [:])
        check(first != second, "hands advance while the dial is cached")
        print("PASS: \(count) checks — clock math, movement, DST, settings persistence/recovery, drift, all palettes and animated rendering")
    }
}
