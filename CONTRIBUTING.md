# Contributing

Keep Still quiet, native, and easy to remove. Prefer a small, understandable change over adding a dependency or service.

1. Fork or branch, then run `make build` and `make test`.
2. Keep all clock drawing in `ClockCore`; the app and screen saver must stay visually consistent.
3. Add meaningful regression coverage when changing time, settings, or lifecycle behavior. `Scripts/Checks.swift` runs without Xcode; `Tests/` provides XCTest coverage in CI.
4. Inspect the result in the app and real macOS screen saver settings. Check both day and night, small previews and full-screen, and Reduce Motion if animation changes.
5. Describe the behavior changed and what was tested. Include an original screenshot for visible changes.

Do not commit generated build products, signing keys, user preferences, personal screenshots, or reference-product assets. No lock-screen impersonation, security bypasses, analytics, or hidden background services.

Use four-space indentation and clear names. Preserve macOS 13 availability unless a change explicitly updates the deployment target and documents why.
