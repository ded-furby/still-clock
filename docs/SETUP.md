# Settle in

## Desktop

Open Still Clock and click **Use as wallpaper**. The clock appears behind your icons on all connected displays. Click **Pause wallpaper** or quit Still to reveal your existing wallpaper immediately. Still does not change your saved desktop picture.

In **On your Mac**, each connected display has a layout selector. Choose **Right clock · Flow** for a monitor to your left: the dial moves toward the adjoining edge, accompanied by a subtle animated line. Leave your primary screen on **Centered clock**. Preferences follow the display's stable identifier across reconnects; portrait displays use a centered dial so it remains legible. Layouts also apply to the system screen saver when its host exposes the display identity.

The app remains in the menu bar after its window closes. Use **On your Mac → Open Still at login** if you want it to return after signing in. macOS may ask you to allow the login item. Launch-at-login is optional and off by default.

## Screen saver

1. In Still, select **On your Mac → Install screen saver**.
2. On macOS 26/27, open **System Settings → Wallpaper → Screen Saver… → Other → Show All → Still Clock**. On macOS 13–15, use **System Settings → Screen Saver**.
3. Choose a start delay, such as five minutes.
4. Set **Lock Screen → Require password after screen saver begins or display is turned off → Immediately** if you want the screen saver to protect your session.
5. Your display-off delay must be longer than the screen-saver delay, or the display will sleep before you see the clock.

The screen saver can run independently after you quit Still. Visual settings are shared with the app in the current user’s private `/Users/Shared/StillClock-<uid>/` folder, with Apple’s `ScreenSaverDefaults` as a local fallback. You can also edit them using the screen saver’s **Options…** sheet. Reopen Still’s window to reload changes made there. A running screen saver picks up app changes the next time it starts.

## Show the clock now

Choose **Start system screen saver** from Still’s menu-bar menu. Verify that you have selected Still Clock in macOS settings and required a password immediately. Move the mouse or press a key to reach Apple’s unlock interface.

You can assign **Start Screen Saver** to a Hot Corner in **Desktop & Dock → Hot Corners…** for an OS-managed shortcut. The app does not remap **Control–Command–Q** or intercept your keyboard globally.

**Preview** fills the display so you can inspect the design. Press any key or click to return. Preview does not lock or secure your session.

## Troubleshooting

| Symptom | Try this |
| --- | --- |
| Still is absent from the list | Click **Other → Show All**. Close and reopen System Settings after installing. |
| First preview is black | Allow the screen saver host a few seconds to launch. If it remains black, choose another saver, then Still. |
| A different screen saver starts | Select Still in macOS settings; the menu command launches the system’s selected saver. |
| Options do not open | Quit and reopen System Settings. You can edit the dial in the Still app as well. |
| Theme changed in Options but wallpaper did not | Reopen Still’s settings window to reload saved preferences. |
| Auto looks different in day and night | Auto follows the Mac’s appearance, not sunrise/sunset or location. |
| No animation on the password screen | That screen is controlled by macOS. Use the protected screen saver workflow above. |
| Clock disappears when the display sleeps | Expected. Change the display-off delay if desired; Still does not prevent sleep. |
| Download is blocked | This build is not notarized. Build from source or use macOS’s standard Open Anyway flow after reviewing the source. Never disable system security. |

## Update or remove

Quit Still, replace the app in Applications, reopen it, then use **Reinstall screen saver**. Existing screen saver preferences are preserved; the installer moves an older bundle to the Trash after the replacement succeeds. Quit and reopen System Settings if it holds the previous module in memory.

To remove: turn off **Open Still at login**, select a different system screen saver, quit Still, and move these items to Trash:

- `/Applications/Still Clock.app`
- `~/Library/Screen Savers/Still Clock.saver`

Your saved wallpaper is untouched. Preferences are small and may be kept for reinstalling. The shared visual settings live in `/Users/Shared/StillClock-<uid>/settings.json`; remove your own StillClock folder if you want to reset them. If desired, remove only `com.dedfurby.StillClock` and `com.dedfurby.StillClock.saver` preferences; do not reset Apple’s screen saver or wallpaper preferences.
