import AppKit
import SwiftUI
import Combine
import ServiceManagement
#if !DIRECT_BUILD
import ClockCore
#endif

@MainActor final class AppController: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    @Published var selectedPage = 0
    @Published var displayNames: [String] = []
    @Published var displays: [ClockDisplay] = []
    @Published var wallpaperEnabled = false
    @Published var launchAtLogin = false
    @Published var message = ""
    @Published var saverInstalled = false
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var wallpaperWindows: [NSWindow] = []
    private var previewWindows: [NSWindow] = []
    private var subscriptions = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var sessionActive = true
    private var displayAwake = true
    private let store = SettingsStore.shared
    private let saverURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Screen Savers/Still Clock.saver")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if handleCommandLine() { return }
        NSApp.setActivationPolicy(.accessory)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        saverInstalled = FileManager.default.fileExists(atPath: saverURL.path)
        setupMenu()
        displayNames = NSScreen.screens.map(\.localizedName)
        displays = NSScreen.screens.map { ClockDisplay(screen: $0) }
        store.$settings.sink { [weak self] value in
            for window in (self?.wallpaperWindows ?? []) + (self?.previewWindows ?? []) {
                (window.contentView as? ClockCanvas)?.settings = value
                (window.contentView as? ClockCanvas)?.layout = value.layout(for: window.screen)
            }
        }.store(in: &subscriptions)
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAwake = false; self?.updatePause() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAwake = true; self?.restoreWallpaper() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sessionActive = false; self?.updatePause() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.sessionActive = true; self?.restoreWallpaper() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.restoreWallpaper() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.displayNames = NSScreen.screens.map(\.localizedName)
                self?.displays = NSScreen.screens.map { ClockDisplay(screen: $0) }
                if self?.wallpaperEnabled == true { self?.rebuildWallpaper() }
            }
        })
        if UserDefaults.standard.bool(forKey: "wallpaperEnabled") { setWallpaper(true) }
        if !CommandLine.arguments.contains("--background"), !wallpaperEnabled { showSettings() }
    }

    private func handleCommandLine() -> Bool {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--render"), args.indices.contains(index + 1) {
            let directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let renderer = ClockRenderer()
                let date = ISO8601DateFormatter().date(from: "2026-10-14T10:08:36Z")!
                for dial in Dial.allCases {
                    var s = ClockSettings(); s.dial = dial; s.timeZoneID = "GMT"; s.scale = 0.87
                    if let data = renderer.image(size: CGSize(width: 1920, height: 1200), date: date, settings: s)?.representation(using: .png, properties: [:]) {
                        try data.write(to: directory.appendingPathComponent("\(dial.rawValue).png"))
                    }
                }
                var s = ClockSettings(); s.appearance = .night; s.timeZoneID = "GMT"; s.scale = 0.87
                if let data = renderer.image(size: CGSize(width: 1920, height: 1200), date: date, settings: s)?.representation(using: .png, properties: [:]) {
                    try data.write(to: directory.appendingPathComponent("night.png"))
                }
                s.appearance = .day; s.dial = .lavender
                if let data = renderer.image(size: CGSize(width: 1920, height: 1080), date: date, settings: s, layout: .flowRight)?.representation(using: .png, properties: [:]) {
                    try data.write(to: directory.appendingPathComponent("companion.png"))
                }
                print("Rendered 10 clock previews to \(directory.path)")
            } catch { fputs("Render failed: \(error)\n", stderr); exit(1) }
            NSApp.terminate(nil); return true
        }
        return false
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Still Clock")
        let menu = NSMenu()
        let items: [(String, Selector?, String)] = [
            ("Still Clock…", #selector(showSettings), ","),
            ("Toggle live wallpaper", #selector(toggleWallpaper), ""),
            ("Preview full screen", #selector(showPreview), "p"),
            ("Start system screen saver", #selector(startScreenSaver), ""),
            ("Screen saver settings…", #selector(openScreenSaverSettings), ""),
            ("", nil, ""), ("Quit Still Clock", #selector(quit), "q")
        ]
        for (title, action, key) in items {
            if title.isEmpty { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self; menu.addItem(item)
        }
        statusItem?.menu = menu
        let appMenu = NSMenu(); let root = NSMenuItem(); root.submenu = menu.copy() as? NSMenu
        appMenu.addItem(root); NSApp.mainMenu = appMenu
    }

    @objc func showSettings() {
        store.reload()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Still Clock"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(hex: 0xF6F4EE)
            window.contentView = NSHostingView(rootView: SettingsView(controller: self, store: store))
            window.delegate = self; window.center(); settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            NSApp.setActivationPolicy(.accessory)
            // Changing activation policy can reorder the app's other windows.
            DispatchQueue.main.async { [weak self] in self?.restoreWallpaper() }
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) { store.reload() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc func toggleWallpaper() { setWallpaper(!wallpaperEnabled) }
    func setWallpaper(_ enabled: Bool) {
        wallpaperEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "wallpaperEnabled")
        if enabled { rebuildWallpaper() } else { closeWallpaper() }
    }
    private func closeWallpaper() {
        for window in wallpaperWindows { (window.contentView as? ClockCanvas)?.stop(); window.close() }
        wallpaperWindows.removeAll()
    }
    private func rebuildWallpaper() {
        closeWallpaper()
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            window.isReleasedWhenClosed = false
            window.title = "Still Wallpaper — \(screen.localizedName)"
            window.setFrame(screen.frame, display: false)
            // Stay above the system's desktop picture, just below Finder's icons.
            // A level near desktopWindow can be covered by WallpaperAgent.
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.canHide = false; window.hidesOnDeactivate = false
            window.ignoresMouseEvents = true; window.hasShadow = false
            let canvas = ClockCanvas(frame: NSRect(origin: .zero, size: screen.frame.size))
            canvas.settings = store.settings; canvas.layout = store.settings.layout(for: screen); canvas.allowDrift = true
            window.contentView = canvas; window.orderFrontRegardless(); wallpaperWindows.append(window)
        }
        updatePause()
    }
    private func restoreWallpaper() {
        guard wallpaperEnabled else { return }
        for window in wallpaperWindows {
            window.orderFrontRegardless()
            window.contentView?.needsDisplay = true
        }
        updatePause()
    }
    private func updatePause() {
        for window in wallpaperWindows { (window.contentView as? ClockCanvas)?.paused = !sessionActive || !displayAwake }
    }

    @objc func showPreview() {
        dismissPreview()
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            window.isReleasedWhenClosed = false; window.setFrame(screen.frame, display: false); window.level = .floating; window.hasShadow = false
            let canvas = ClockCanvas(frame: NSRect(origin: .zero, size: screen.frame.size))
            canvas.settings = store.settings; canvas.layout = store.settings.layout(for: screen); canvas.allowDrift = true
            window.contentView = canvas; window.makeKeyAndOrderFront(nil); previewWindows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismissPreview(); return nil
        }
    }
    private func dismissPreview() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
        for window in previewWindows { (window.contentView as? ClockCanvas)?.stop(); window.close() }
        previewWindows.removeAll()
    }

    func installScreenSaver() {
        do {
            guard let source = Bundle.main.url(forResource: "Still Clock", withExtension: "saver") else {
                throw NSError(domain: "StillClock", code: 1, userInfo: [NSLocalizedDescriptionKey: "Open the packaged Still Clock.app to install its screen saver. Build it with Scripts/build.sh."])
            }
            let fm = FileManager.default
            try fm.createDirectory(at: saverURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let staging = saverURL.deletingLastPathComponent().appendingPathComponent(".StillClock-\(UUID().uuidString).saver")
            try fm.copyItem(at: source, to: staging)
            if fm.fileExists(atPath: saverURL.path) {
                let backup = saverURL.deletingLastPathComponent().appendingPathComponent(".StillClock-backup-\(UUID().uuidString).saver")
                try fm.moveItem(at: saverURL, to: backup)
                do { try fm.moveItem(at: staging, to: saverURL) }
                catch { try? fm.moveItem(at: backup, to: saverURL); throw error }
                try? fm.trashItem(at: backup, resultingItemURL: nil)
            } else { try fm.moveItem(at: staging, to: saverURL) }
            saverInstalled = true
            message = "Installed. Choose Still Clock in macOS Screen Saver settings."
            openScreenSaverSettings()
        } catch { message = error.localizedDescription }
    }
    @objc func openScreenSaverSettings() {
        let destination = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
            ? "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"
            : "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"
        NSWorkspace.shared.open(URL(string: destination)!)
    }
    func openLockSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension")!)
    }
    @objc func startScreenSaver() {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            if let error { DispatchQueue.main.async { self?.message = error.localizedDescription } }
        }
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { message = "Allow Still Clock in System Settings → General → Login Items." }
        } catch { message = error.localizedDescription }
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { dismissPreview(); closeWallpaper() }
}
