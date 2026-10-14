import AppKit
import ScreenSaver

@main struct SmokeTest {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        guard CommandLine.arguments.count == 2,
              let bundle = Bundle(path: CommandLine.arguments[1]) else { fatalError("Pass the .saver path") }
        try bundle.loadAndReturnError()
        guard let type = bundle.principalClass as? ScreenSaverView.Type else { fatalError("Screen saver principal class is not loadable") }
        for preview in [false, true] {
            guard let view = type.init(frame: NSRect(x: 0, y: 0, width: 960, height: 600), isPreview: preview) else { fatalError("Screen saver initialization failed") }
            precondition(view.isPreview == preview)
            precondition(view.hasConfigureSheet && view.configureSheet != nil)
            view.startAnimation(); precondition(view.isAnimating)
            guard let context = CGContext(data: nil, width: 960, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("No context") }
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            view.animateOneFrame(); view.draw(view.bounds)
            precondition(context.makeImage() != nil)
            view.stopAnimation(); precondition(!view.isAnimating)
            print("PASS: bundle loading, \(preview ? "preview" : "full-screen") initialization, configuration sheet, drawing and animation lifecycle")
        }
    }
}
