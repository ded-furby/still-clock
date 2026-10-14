import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppController()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
