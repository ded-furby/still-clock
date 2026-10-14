import XCTest
@testable import ClockCore

final class ClockCoreTests: XCTestCase {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    func testMidnightAndNoon() {
        for hour in ["00", "12"] {
            let angles = HandAngles(date: date("2026-10-14T\(hour):00:00Z"), timeZone: TimeZone(secondsFromGMT: 0)!, movement: .sweep)
            XCTAssertEqual(angles.hour, 0, accuracy: 0.000001)
            XCTAssertEqual(angles.minute, 0, accuracy: 0.000001)
            XCTAssertEqual(angles.second, 0, accuracy: 0.000001)
        }
    }
    func testHourHandMovesBetweenIndices() {
        let angles = HandAngles(date: date("2026-10-14T03:30:00Z"), timeZone: TimeZone(secondsFromGMT: 0)!, movement: .quartz)
        XCTAssertEqual(angles.hour, 3.5 * .pi / 6, accuracy: 0.000001)
        XCTAssertEqual(angles.minute, .pi, accuracy: 0.000001)
    }
    func testMovementsHaveDistinctCadence() {
        XCTAssertEqual(Movement.quartz.seconds(17.92), 17)
        XCTAssertEqual(Movement.mechanical.seconds(17.92), 17.875)
        XCTAssertEqual(Movement.sweep.seconds(17.92), 17.92)
        XCTAssertEqual(Movement.mechanical.frameInterval, 0.125)
        XCTAssertEqual(3600 / Movement.mechanical.frameInterval, 28800)
    }
    func testHalfHourTimeZone() {
        let angles = HandAngles(date: date("2026-10-14T00:00:00Z"), timeZone: TimeZone(identifier: "Asia/Kolkata")!, movement: .quartz)
        XCTAssertEqual(angles.hour, 5.5 * .pi / 6, accuracy: 0.000001)
        XCTAssertEqual(angles.minute, .pi, accuracy: 0.000001)
    }
    func testSydneyDSTTransition() {
        let zone = TimeZone(identifier: "Australia/Sydney")!
        let before = HandAngles(date: date("2026-10-03T15:59:00Z"), timeZone: zone, movement: .quartz)
        let after = HandAngles(date: date("2026-10-03T16:00:00Z"), timeZone: zone, movement: .quartz)
        XCTAssertEqual(before.hour, (1 + 59.0 / 60) * .pi / 6, accuracy: 0.000001)
        XCTAssertEqual(after.hour, .pi / 2, accuracy: 0.000001)
    }
    func testInvalidSettingsAreBounded() {
        var settings = ClockSettings()
        settings.scale = .infinity; settings.timeZoneID = "Invalid/Nowhere"; settings.validate()
        XCTAssertEqual(settings.scale, 0.82); XCTAssertEqual(settings.timeZoneID, "system")
        settings.scale = -1; settings.validate(); XCTAssertEqual(settings.scale, 0.45)
        settings.scale = 10; settings.validate(); XCTAssertEqual(settings.scale, 0.94)
    }
    func testSettingsRoundTrip() throws {
        var s = ClockSettings(); s.appearance = .night; s.dial = .sage; s.showDate = true; s.scale = 0.56
        XCTAssertEqual(try JSONDecoder().decode(ClockSettings.self, from: JSONEncoder().encode(s)), s)
    }
    func testNightAppearanceFollowsPreference() {
        var s = ClockSettings()
        XCTAssertFalse(s.isNight(systemDark: true))
        s.appearance = .night; XCTAssertTrue(s.isNight(systemDark: false))
        s.appearance = .automatic; XCTAssertTrue(s.isNight(systemDark: true)); XCTAssertFalse(s.isNight(systemDark: false))
    }
    func testPixelShiftStaysBoundedAndContinuous() {
        for t in stride(from: 0.0, through: 100000, by: 17) {
            let a = ClockGeometry.drift(at: t, amplitude: 12)
            let b = ClockGeometry.drift(at: t + 1 / 30, amplitude: 12)
            XCTAssertLessThanOrEqual(abs(a.x), 12); XCTAssertLessThanOrEqual(abs(a.y), 12)
            XCTAssertLessThan(abs(b.x - a.x), 0.003); XCTAssertLessThan(abs(b.y - a.y), 0.003)
        }
    }
    @MainActor func testRenderingAllPalettesAtTinyAndRetinaSizes() {
        let renderer = ClockRenderer()
        for dial in Dial.allCases {
            for appearance in [AppearanceMode.day, .night] {
                var s = ClockSettings(); s.dial = dial; s.appearance = appearance
                for size in [CGSize(width: 160, height: 100), CGSize(width: 1440, height: 900)] {
                    let image = renderer.image(size: size, date: date("2026-10-14T10:08:36Z"), settings: s)
                    XCTAssertEqual(image?.pixelsWide, Int(size.width)); XCTAssertEqual(image?.pixelsHigh, Int(size.height))
                    XCTAssertNotNil(image?.representation(using: .png, properties: [:]))
                }
            }
        }
    }
}
