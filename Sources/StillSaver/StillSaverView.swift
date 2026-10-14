import ScreenSaver
import SwiftUI

@objc(StillSaverView)
@MainActor public final class StillSaverView: ScreenSaverView {
    private let renderer = ClockRenderer()
    private var settings = ClockSettings()
    private var sheet: NSWindow?
    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        refreshSettings()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); refreshSettings() }
    private func refreshSettings() {
        SettingsStore.shared.reload()
        settings = SettingsStore.shared.settings
        animationTimeInterval = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || !settings.showSeconds ? 1 : settings.movement.frameInterval
        needsDisplay = true
    }
    public override func startAnimation() { refreshSettings(); super.startAnimation() }
    public override func stopAnimation() { super.stopAnimation() }
    public override func animateOneFrame() { needsDisplay = true }
    public override var isOpaque: Bool { true }
    public override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        renderer.draw(in: context, size: bounds.size, settings: settings,
                      backingScale: window?.backingScaleFactor ?? 2, systemDark: dark, allowDrift: !isPreview)
    }
    public override var hasConfigureSheet: Bool { true }
    public override var configureSheet: NSWindow? {
        if sheet == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
                                  styleMask: [.titled], backing: .buffered, defer: false)
            window.title = "Still Clock"
            window.contentView = NSHostingView(rootView: SaverOptions(store: SettingsStore.shared) { [weak self, weak window] in
                guard let window else { return }
                self?.refreshSettings()
                if let parent = window.sheetParent { parent.endSheet(window) } else { window.orderOut(nil) }
            })
            sheet = window
        }
        return sheet
    }
}

private struct SaverOptions: View {
    @ObservedObject var store: SettingsStore
    var done: () -> Void
    var body: some View {
        HStack(spacing: 24) {
            ClockPreview(settings: store.settings).frame(width: 290, height: 400).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 16) {
                Text("Still Clock").font(.system(size: 24, design: .serif))
                Picker("Dial", selection: $store.settings.dial) { ForEach(Dial.allCases) { Text($0.title).tag($0) } }
                Picker("Light", selection: $store.settings.appearance) { ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) } }
                Picker("Movement", selection: $store.settings.movement) { ForEach(Movement.allCases) { Text($0.title).tag($0) } }
                Text("Scale").font(.caption)
                Slider(value: $store.settings.scale, in: 0.45...0.94)
                Toggle("Second hand", isOn: $store.settings.showSeconds)
                Toggle("Numerals", isOn: $store.settings.showNumerals)
                Toggle("Date", isOn: $store.settings.showDate)
                Toggle("Gentle pixel shift", isOn: $store.settings.drift)
                Spacer()
                Button("Done", action: done).keyboardShortcut(.defaultAction).frame(maxWidth: .infinity, alignment: .trailing)
            }.frame(width: 240)
        }.padding(28).frame(width: 620, height: 480)
    }
}
