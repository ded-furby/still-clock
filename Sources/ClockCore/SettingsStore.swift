import AppKit
import Combine
import ScreenSaver

@MainActor public final class SettingsStore: ObservableObject {
    public static let domain = "com.dedfurby.StillClock.saver"
    public static let shared = SettingsStore()
    @Published public var settings: ClockSettings { didSet { save() } }
    @Published public private(set) var syncMessage = ""
    private let defaults: UserDefaults
    private let sharedURL: URL?
    public init(defaults: UserDefaults? = nil, sharedSettingsURL: URL? = nil) {
        self.defaults = defaults ?? ScreenSaverDefaults(forModuleWithName: Self.domain) ?? .standard
        // Modern macOS isolates the screen saver host's defaults from the companion app.
        // Share only our visual preferences in a private, per-user folder accessible to both.
        sharedURL = sharedSettingsURL ?? (defaults == nil ? URL(fileURLWithPath: "/Users/Shared/StillClock-\(getuid())/settings.json") : nil)
        let sharedData = sharedURL.flatMap { try? Data(contentsOf: $0) }
        if let data = sharedData ?? self.defaults.data(forKey: "settingsV1"),
           var decoded = try? JSONDecoder().decode(ClockSettings.self, from: data) {
            decoded.validate()
            settings = decoded
        } else { settings = ClockSettings() }
        if sharedURL != nil { save() }
    }
    public func reload() {
        defaults.synchronize()
        let sharedData = sharedURL.flatMap { try? Data(contentsOf: $0) }
        if let data = sharedData ?? defaults.data(forKey: "settingsV1"),
           var updated = try? JSONDecoder().decode(ClockSettings.self, from: data) {
            updated.validate()
            if updated != settings { settings = updated }
        }
    }
    private func save() {
        var safe = settings
        safe.validate()
        if let data = try? JSONEncoder().encode(safe) {
            defaults.set(data, forKey: "settingsV1")
            defaults.synchronize()
            if let sharedURL {
                do {
                    let directory = sharedURL.deletingLastPathComponent()
                    let fm = FileManager.default
                    if !fm.fileExists(atPath: directory.path) {
                        try fm.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
                    }
                    let attributes = try fm.attributesOfItem(atPath: directory.path)
                    guard attributes[.type] as? FileAttributeType == .typeDirectory,
                          (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else {
                        throw CocoaError(.fileWriteNoPermission)
                    }
                    try data.write(to: sharedURL, options: .atomic)
                    syncMessage = ""
                } catch {
                    syncMessage = "Desktop settings saved locally. Shared screen saver preferences could not be written: \(error.localizedDescription)"
                }
            }
        }
    }
}
