import SwiftUI
import QuartzCore

/// 番茄钟最小版：专注 25 分钟 / 休息 5 分钟，结束翻页提示 + 提示音。
/// 对应原版 Pomodoro（FUN_100299468/FUN_100299588 的重复 Timer 节拍）：
/// Timer 负责"发现变化"，SplitFlap 负责"演出变化"。
@MainActor
final class PomodoroModel: ObservableObject {
    enum Phase: String {
        case focus = "专注"
        case rest = "休息"
    }

    @Published var phase: Phase = .focus
    @Published var remaining: TimeInterval = 25 * 60
    @Published var running = false

    var focusMinutes: Int = 25
    var restMinutes: Int = 5

    private var timer: Timer?
    private var lastWhirrTick: Int?

    deinit { timer?.invalidate() }

    func toggle() {
        if running { pause() } else { start() }
    }

    func start() {
        running = true
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        running = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        remaining = TimeInterval((phase == .focus ? focusMinutes : restMinutes) * 60)
        lastWhirrTick = nil
    }

    func switchPhase() {
        phase = (phase == .focus) ? .rest : .focus
        reset()
    }

    private func tick() {
        remaining = max(0, remaining - 0.25)
        let secs = Int(remaining.rounded(.up))

        // 最后一分钟每秒一声轻响（"落定"音的节流用法）
        if remaining <= 60, remaining > 0, lastWhirrTick != secs {
            lastWhirrTick = secs
            FlipSoundPlayer.shared.playLanding(minGap: 0.9)
        }

        if remaining <= 0 {
            pause()
            FlipSoundPlayer.shared.play(mode: .slow)
            HapticsManager.shared.tap()
            switchPhase()
        }
    }

    func formatted() -> String {
        let total = Int(max(0, remaining.rounded(.up)))
        return String(format: "%02d%02d", total / 60, total % 60)
    }
}

struct PomodoroView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var model = PomodoroModel()
    @StateObject private var coordinator = SplitFlapRowDrumCoordinator(initialText: "2500")

    var body: some View {
        GeometryReader { geo in
            let cardW = (geo.size.width - 40 - 8 * 3) / 4
            let cardH = cardW * 1.45

            ZStack {
                settings.theme.background.ignoresSafeArea()
                VStack(spacing: 30) {
                    Text(model.phase.rawValue)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(settings.theme.digitColor.opacity(0.75))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())

                    // 倒计时翻页（复用整排协调器：逐格错峰翻页）
                    HStack(spacing: 8) {
                        ForEach(0..<coordinator.cells.count, id: \.self) { i in
                            SplitFlapCard(
                                model: coordinator.cells[i],
                                theme: settings.theme,
                                size: CGSize(width: cardW, height: cardH))
                        }
                    }

                    HStack(spacing: 18) {
                        Button {
                            HapticsManager.shared.tap()
                            model.toggle()
                        } label: {
                            Label(model.running ? "暂停" : "开始",
                                  systemImage: model.running ? "pause.fill" : "play.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(settings.theme.background)
                                .padding(.horizontal, 30).padding(.vertical, 12)
                                .background(settings.theme.digitColor, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(settings.theme.digitColor.opacity(0.9))
                                .frame(width: 46, height: 46)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(settings.theme.digitColor.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(.trailing, 18).padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
            .onAppear { FlipSoundPlayer.shared.prepare() }
            .onReceive(model.$remaining) { _ in
                coordinator.setText(model.formatted())
            }
            .onChange(of: model.phase) { _ in
                coordinator.setText(model.formatted())
            }
        }
    }
}
