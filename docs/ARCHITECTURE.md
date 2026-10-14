# Architecture

Still uses native AppKit, SwiftUI, Core Graphics, ScreenSaver, and ServiceManagement. There are no third-party dependencies or outbound application network calls.

## One dial, three hosts

`ClockRenderer` draws into any `CGContext`. A 1,000-unit coordinate space gives consistent geometry at every size. A transparent bitmap caches the dial marks, numerals, and shadows for the current palette, appearance, size, and numeral setting. Every frame composites that image and draws the hands from the current wall-clock time.

`ClockCanvas` is the AppKit view used by the SwiftUI preview and wallpaper windows. Timers capture it weakly, run in the common run-loop mode, and stop when it leaves a window. The desktop controller pauses views for display sleep and inactive sessions; invisible windows do not request drawing. Reduced Motion limits updates to once per second.

`StillSaverView` is exported as the Objective-C principal class in a `.saver` bundle. macOS owns its animation timer, lifecycle, locking, and screen-saver surfaces. It calls `animateOneFrame`, which requests a normal AppKit draw. The app embeds the same bundle in its Resources directory for installation.

## Time

Angles come from Gregorian calendar components in the selected time zone, including nanoseconds. This delegates daylight-saving and local-time updates to Foundation. Sweep preserves fractional seconds, mechanical quantizes to 1/8 second, and quartz quantizes to whole seconds. The hour and minute hands include lower-order components. Clock values are derived from `Date()` each frame, never accumulated timer deltas.

## Preferences

`ClockSettings` is a versioned JSON payload. It is shared in `/Users/Shared/StillClock-<uid>/settings.json`, in a private directory owned by the current user with mode 0700. This avoids relying on identical defaults containers between the app and Apple’s sandboxed screen saver host. `ScreenSaverDefaults`, under `com.dedfurby.StillClock.saver`, is the local fallback. Decode failures revert to known defaults. Loaded scale and timezone values are validated. The app and screen saver options use the same schema. App-only wallpaper/login behavior is separate from visual settings.

## Desktop windows

One borderless, mouse-transparent window per display is placed just below the desktop-icon level, above the system desktop picture. The windows cannot hide with the settings app. They join desktop Spaces, restore their order after wake/unlock/Space changes, and rebuild after display configuration changes. The original wallpaper is never overwritten. This is not an overlay on the login window, and it does not attempt to bypass macOS’s secure UI.

Display layouts are keyed by Core Graphics display UUID, independent of monitor ordering. The optional `displayLayouts` field keeps 1.0.0 preference files compatible. `DialPlacement` keeps the right-aligned composition inside the display and falls back to centered on portrait screens. The companion flow is drawn in the shared renderer at 30 fps and freezes under Reduce Motion; the clock itself still advances.

## Packaging and trust

`build.sh` compiles the app and screen saver with `swiftc`, combines architecture outputs with `lipo`, writes bundle metadata, embeds the screen saver, and signs from the inside out. `SIGNING_IDENTITY` can select an available certificate; the default is ad-hoc signing. The package script creates a universal DMG and ZIP plus hashes. It does not claim notarization. A production notarization pipeline needs the owner’s Developer ID certificate and Apple notarization credentials.

## Intentional boundaries

- No private lock-screen APIs, global input hooks, administrator helper, or authentication changes.
- No screen capture, microphone, camera, Accessibility permission, or network access required by Still.
- No always-awake assertion; the user’s display sleep policy wins.
- Pixel drift reduces static exposure but is not a burn-in warranty.
- Hot-plug/Spaces behavior, macOS 13–26, and Intel execution require broader hardware validation beyond compiling the universal binaries.
