import SwiftUI
#if !DIRECT_BUILD
import ClockCore
#endif

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var store: SettingsStore
    private var page: Int { controller.selectedPage }
    private let ink = Color(nsColor: NSColor(hex: 0x223B34))
    private let muted = Color(nsColor: NSColor(hex: 0x7B8179))
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(page == 0 ? "MAKE TIME YOUR OWN" : page == 1 ? "AT HOME ON YOUR MAC" : "A SMALL MOMENT OF STILLNESS")
                            .font(.system(size: 10, weight: .semibold)).tracking(2.2).foregroundColor(muted)
                        Text(page == 0 ? "Time, beautifully kept." : page == 1 ? "Every screen. One clock." : "Less noise. More time.")
                            .font(.system(size: 32, weight: .regular, design: .serif)).foregroundColor(ink)
                    }
                    Spacer()
                    Button { controller.showPreview() } label: { Label("Preview", systemImage: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(.bordered).controlSize(.large).help("Full-screen preview. Press any key to return.")
                }.padding(.bottom, 26)
                if page == 0 { appearancePage }
                if page == 1 { ScrollView { setupPage }.scrollIndicators(.hidden) }
                if page == 2 { aboutPage }
                Spacer(minLength: 12)
                HStack {
                    Circle().fill(controller.wallpaperEnabled ? Color.green.opacity(0.65) : muted.opacity(0.4)).frame(width: 6, height: 6)
                    Text(controller.wallpaperEnabled ? "Live on your desktop" : "Ready when you are").font(.system(size: 11)).foregroundColor(muted)
                    Spacer()
                    Text("NATIVE BY NATURE · STILL 1.0").font(.system(size: 9, weight: .medium)).tracking(1.5).foregroundColor(muted)
                }.padding(.top, 12)
            }.padding(30).padding(.top, 18).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: NSColor(hex: 0xF6F4EE)))
        }.frame(width: 1120, height: 760).preferredColorScheme(.light)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "clock").font(.system(size: 26, weight: .ultraLight))
                Text("STILL").font(.system(size: 23, weight: .medium, design: .serif)).tracking(5)
            }.foregroundColor(Color(nsColor: NSColor(hex: 0xF0EBDD))).padding(.bottom, 8)
            Text("A little less hurry.").font(.system(size: 11)).foregroundColor(.white.opacity(0.42))
            VStack(spacing: 7) {
                nav("The dial", symbol: "circle.lefthalf.filled", index: 0)
                nav("On your Mac", symbol: "desktopcomputer", index: 1)
                nav("About Still", symbol: "sparkle", index: 2)
            }.padding(.top, 49)
            Spacer()
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1).padding(.bottom, 20)
            Image(systemName: controller.wallpaperEnabled ? "waveform.path" : "minus").font(.system(size: 24, weight: .ultraLight)).foregroundColor(.white.opacity(0.55))
            Text(controller.wallpaperEnabled ? "In its element." : "Make yourself at home.")
                .font(.system(size: 15, design: .serif)).foregroundColor(.white.opacity(0.86)).padding(.top, 12)
            Text("Your clock, quietly present.").font(.system(size: 10)).foregroundColor(.white.opacity(0.4)).padding(.top, 5)
            Button { controller.toggleWallpaper() } label: {
                Text(controller.wallpaperEnabled ? "Pause wallpaper" : "Use as wallpaper")
                    .font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 10)
            }.buttonStyle(.plain).background(Color.white.opacity(0.12)).foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7)).padding(.top, 17)
        }.padding(.horizontal, 22).padding(.top, 66).padding(.bottom, 29)
            .frame(width: 206).background(ink)
    }
    private func nav(_ label: String, symbol: String, index: Int) -> some View {
        Button { controller.selectedPage = index } label: {
            HStack(spacing: 12) { Image(systemName: symbol).frame(width: 16); Text(label); Spacer() }
                .font(.system(size: 12, weight: page == index ? .semibold : .regular)).padding(12)
                .foregroundColor(.white.opacity(page == index ? 1 : 0.5))
                .background(page == index ? Color.white.opacity(0.11) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
    private var appearancePage: some View {
        HStack(alignment: .top, spacing: 25) {
            VStack(alignment: .leading, spacing: 16) {
                ClockPreview(settings: store.settings).frame(width: 494, height: 487)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(0.04)))
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.settings.appearance == .night ? "After hours" : store.settings.dial.title)
                            .font(.system(size: 19, design: .serif)).foregroundColor(ink)
                        Text(store.settings.movement.description).font(.system(size: 11)).foregroundColor(muted)
                    }
                    Spacer()
                    Text(store.settings.timeZoneID == "system" ? "LOCAL TIME" : store.settings.timeZoneID.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.system(size: 9, weight: .medium)).tracking(1).foregroundColor(muted).padding(.top, 6)
                }
            }
            VStack(alignment: .leading, spacing: 21) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("LIGHT")
                    Picker("Appearance", selection: $store.settings.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0 == .automatic ? "Auto" : $0.title).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden()
                }
                VStack(alignment: .leading, spacing: 13) {
                    HStack { sectionLabel("PALETTE"); Spacer(); Text(store.settings.dial.title).font(.system(size: 10)).foregroundColor(muted) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 13) {
                        ForEach(Dial.allCases) { dial in
                            Button { store.settings.dial = dial } label: {
                                Circle().fill(Color(nsColor: DialPalette.make(dial, night: false).background))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(.black.opacity(0.07), lineWidth: 1))
                                    .padding(4).overlay(Circle().stroke(dial == store.settings.dial ? ink.opacity(0.7) : .clear, lineWidth: 1.2))
                            }.buttonStyle(.plain).help(dial.title).accessibilityLabel(dial.title)
                                .accessibilityAddTraits(dial == store.settings.dial ? .isSelected : [])
                        }
                    }
                }
                divider
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("MOVEMENT")
                    Picker("Movement", selection: $store.settings.movement) {
                        ForEach(Movement.allCases) { Text($0 == .mechanical ? "Mech." : $0.title).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack { sectionLabel("SCALE"); Spacer(); Text("\(Int(store.settings.scale * 100))%").font(.system(size: 10)).monospacedDigit().foregroundColor(muted) }
                    Slider(value: $store.settings.scale, in: 0.45...0.94).tint(ink).accessibilityLabel("Clock scale")
                }
                divider
                VStack(spacing: 12) {
                    detailToggle("Second hand", value: $store.settings.showSeconds)
                    detailToggle("Numerals", value: $store.settings.showNumerals)
                    detailToggle("Quiet date", value: $store.settings.showDate)
                    detailToggle("Gentle pixel shift", value: $store.settings.drift)
                }
                Picker("Time zone", selection: $store.settings.timeZoneID) {
                    Text("Local time").tag("system")
                    Text("Sydney").tag("Australia/Sydney")
                    Text("London").tag("Europe/London")
                    Text("New York").tag("America/New_York")
                    Text("Tokyo").tag("Asia/Tokyo")
                    Text("UTC").tag("GMT")
                }.font(.system(size: 11))
            }.frame(width: 233).padding(.top, 4)
        }
    }
    private var setupPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            setupCard("01", title: "A living desktop", subtitle: "The dial sits behind your icons on every connected display.") {
                ForEach(controller.displays) { display in
                    HStack {
                        Label(display.name, systemImage: "display").font(.system(size: 11)).foregroundColor(ink)
                        Spacer()
                        Picker("Layout for \(display.name)", selection: Binding(
                            get: { store.settings.displayLayouts?[display.id] ?? .centered },
                            set: { layout in
                                var layouts = store.settings.displayLayouts ?? [:]
                                layouts[display.id] = layout
                                store.settings.displayLayouts = layouts
                            })) {
                                ForEach(DisplayLayout.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().frame(width: 180)
                    }
                }
                Toggle("Live wallpaper", isOn: Binding(get: { controller.wallpaperEnabled }, set: controller.setWallpaper)).toggleStyle(.switch).tint(ink)
                Toggle("Open Still at login", isOn: Binding(get: { controller.launchAtLogin }, set: controller.setLaunchAtLogin)).toggleStyle(.switch).tint(ink)
            }
            setupCard("02", title: "Beautiful while you’re away", subtitle: "Install once, then select Still Clock in macOS Screen Saver settings.") {
                HStack {
                    Button(controller.saverInstalled ? "Reinstall screen saver" : "Install screen saver") { controller.installScreenSaver() }.buttonStyle(.borderedProminent).tint(ink)
                    Button("Choose screen saver…") { controller.openScreenSaverSettings() }.buttonStyle(.bordered)
                }
            }
            setupCard("03", title: "Make it a protected screen saver", subtitle: "In Lock Screen settings, require a password immediately. Set your display-off delay longer than your screen-saver delay.") {
                HStack {
                    Button("Lock Screen settings…") { controller.openLockSettings() }.buttonStyle(.bordered)
                    Button("Start system screen saver") { controller.startScreenSaver() }.buttonStyle(.bordered)
                }
                Text("macOS owns the sign-in screen. Still animates in the screen saver; it does not replace the password screen or run while the display is asleep.")
                    .font(.system(size: 11)).foregroundColor(muted).fixedSize(horizontal: false, vertical: true)
            }
            if !store.syncMessage.isEmpty { Text(store.syncMessage).font(.system(size: 11)).foregroundColor(.orange) }
            if !controller.message.isEmpty { Text(controller.message).font(.system(size: 12)).foregroundColor(ink).textSelection(.enabled) }
        }
    }
    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 23) {
            ClockPreview(settings: store.settings).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 16))
            Text("A clock that belongs in the room.").font(.system(size: 27, design: .serif)).foregroundColor(ink)
            Text("Sculpted indices. Warm light. A second hand with somewhere to be. Still is a native macOS clock for your desktop and screen saver, made to feel as considered as the things around it.")
                .font(.system(size: 14)).foregroundColor(muted).lineSpacing(5)
            HStack(spacing: 25) {
                Label("No accounts", systemImage: "person.crop.circle.badge.checkmark")
                Label("No analytics", systemImage: "eye.slash")
                Label("Works offline", systemImage: "wifi.slash")
            }.font(.system(size: 12)).foregroundColor(ink)
            Link("Source, installation & help ↗", destination: URL(string: "https://github.com/ded-furby/still-clock")!).font(.system(size: 12))
        }
    }
    private var divider: some View { Rectangle().fill(ink.opacity(0.1)).frame(height: 1) }
    private func sectionLabel(_ text: String) -> some View { Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundColor(muted) }
    private func detailToggle(_ text: String, value: Binding<Bool>) -> some View {
        Toggle(text, isOn: value).toggleStyle(.switch).controlSize(.mini).font(.system(size: 11)).tint(ink)
    }
    private func setupCard<Content: View>(_ number: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 22) {
            Text(number).font(.system(size: 14, design: .serif)).foregroundColor(muted).padding(.top, 4)
            VStack(alignment: .leading, spacing: 13) {
                Text(title).font(.system(size: 21, design: .serif)).foregroundColor(ink)
                Text(subtitle).font(.system(size: 12)).foregroundColor(muted).fixedSize(horizontal: false, vertical: true)
                content().font(.system(size: 12))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
