import SwiftUI

@main
struct ZenFlipClockApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
        }
    }
}

/// 用户偏好（对应原版设置页；存储键沿用 UserDefaults）
@MainActor
final class AppSettings: ObservableObject {
    @Published var themeRaw: String {
        didSet { UserDefaults.standard.set(themeRaw, forKey: "clockTheme") }
    }
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var secondsVisible: Bool {
        didSet { UserDefaults.standard.set(secondsVisible, forKey: "secondsVisible") }
    }
    @Published var digitFontOverride: String {
        didSet { UserDefaults.standard.set(digitFontOverride, forKey: "digitFontOverride") }
    }

    init() {
        let d = UserDefaults.standard
        themeRaw = d.string(forKey: "clockTheme") ?? ClockTheme.classic.rawValue
        soundEnabled = d.object(forKey: "soundEnabled") as? Bool ?? true
        hapticsEnabled = d.object(forKey: "hapticsEnabled") as? Bool ?? true
        secondsVisible = d.object(forKey: "secondsVisible") as? Bool ?? false
        digitFontOverride = d.string(forKey: "digitFontOverride") ?? ""
    }

    var theme: ClockTheme { ClockTheme(rawValue: themeRaw) ?? .classic }

    func applyGlobalToggles() {
        FlipSoundPlayer.shared.isEnabled = soundEnabled
        HapticsManager.shared.isEnabled = hapticsEnabled
        ClockTheme.fontOverrideName = digitFontOverride.isEmpty ? nil : digitFontOverride
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showControls = false
    @State private var showSettings = false
    @State private var showPomodoro = false
    @State private var hideTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            ClockView()

            if showControls {
                VStack {
                    HStack(spacing: 14) {
                        Spacer()
                        controlButton(icon: "gearshape.fill") {
                            showSettings = true
                        }
                        controlButton(icon: "timer") {
                            showPomodoro = true
                        }
                    }
                    .padding(.trailing, 18)
                    .padding(.top, 8)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showControls.toggle()
            scheduleHide()
        }
        .onAppear { settings.applyGlobalToggles() }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showPomodoro) {
            PomodoroView()
                .environmentObject(settings)
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        let task = DispatchWorkItem { withAnimation(.easeOut(duration: 0.3)) { showControls = false } }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsManager.shared.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(settings.theme.digitColor.opacity(0.85))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
