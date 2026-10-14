import AppKit
import SwiftUI

@MainActor public final class ClockCanvas: NSView {
    public var settings = ClockSettings() { didSet { if oldValue != settings { restartTimer(); needsDisplay = true } } }
    public var allowDrift = false
    public var externalAnimation = false
    public var paused = false { didSet { restartTimer() } }
    public var fixedDate: Date?
    private var timer: Timer?
    private let renderer = ClockRenderer()
    public override var isOpaque: Bool { true }
    public override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Analogue clock")
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    deinit { timer?.invalidate() }
    public override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); restartTimer() }
    public override func viewDidChangeEffectiveAppearance() { needsDisplay = true }
    public override func viewDidChangeBackingProperties() { needsDisplay = true }
    public func stop() { timer?.invalidate(); timer = nil }
    public func restartTimer() {
        stop()
        guard window != nil, !paused, !externalAnimation, fixedDate == nil else { return }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let interval = !settings.showSeconds ? 1 : reduced ? 1 : settings.movement.frameInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.window?.occlusionState.contains(.visible) == true { self.needsDisplay = true }
        }
        timer.tolerance = min(0.015, interval * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        renderer.draw(in: context, size: bounds.size, date: fixedDate ?? Date(), settings: settings,
                      backingScale: window?.backingScaleFactor ?? 2, systemDark: dark, allowDrift: allowDrift)
    }
    public override func accessibilityValue() -> Any? {
        let formatter = DateFormatter()
        formatter.timeZone = settings.timeZone
        formatter.timeStyle = .medium
        return formatter.string(from: fixedDate ?? Date())
    }
}

public struct ClockPreview: NSViewRepresentable {
    public var settings: ClockSettings
    public init(settings: ClockSettings) { self.settings = settings }
    public func makeNSView(context: Context) -> ClockCanvas { ClockCanvas(frame: .zero) }
    public func updateNSView(_ view: ClockCanvas, context: Context) { view.settings = settings }
}
