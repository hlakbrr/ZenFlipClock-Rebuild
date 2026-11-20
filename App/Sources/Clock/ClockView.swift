import SwiftUI

/// 翻页时钟主界面：一行 4 格（HH:MM），可选秒行。
/// 布局随可用空间自适应（原版时钟墙即全屏铺满）。
struct ClockView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var coordinator = SplitFlapRowDrumCoordinator(initialText: "--:--")
    @StateObject private var secondsCoordinator = SplitFlapRowDrumCoordinator(initialText: "--")

    var body: some View {
        GeometryReader { geo in
            let theme = settings.theme
            let showSeconds = settings.secondsVisible
            let gap: CGFloat = 10
            let secondGap: CGFloat = 6
            let rows: CGFloat = showSeconds ? 2 : 1
            let verticalPadding: CGFloat = 24

            // 尺寸推导：卡片高 = min(可用高的均摊, 可用宽/格数 * 1.45)
            let availW = geo.size.width - 32
            let availH = geo.size.height - verticalPadding * 2
            let cardH1 = min(availH / rows - gap, (availW - gap * 3) / 4 * 1.45)
            let cardW1 = cardH1 / 1.45
            let cardH2 = min(96, cardH1 * 0.38)
            let cardW2 = cardH2 / 1.45

            VStack(spacing: gap * 1.6) {
                HStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { i in
                        SplitFlapCard(model: coordinator.cells[i], theme: theme, size: CGSize(width: cardW1, height: cardH1))
                    }
                }
                if showSeconds {
                    HStack(spacing: secondGap) {
                        ForEach(0..<2, id: \.self) { i in
                            SplitFlapCard(model: secondsCoordinator.cells[i], theme: theme, size: CGSize(width: cardW2, height: cardH2))
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .background(theme.background.ignoresSafeArea())
            .onAppear {
                coordinator.mode = .hhmm
                coordinator.startClock()
                if showSeconds {
                    secondsCoordinator.mode = .ss
                    secondsCoordinator.startClock(interval: 0.25)
                }
            }
            .onDisappear {
                coordinator.stop()
                secondsCoordinator.stop()
            }
            .onChange(of: showSeconds) { visible in
                if visible {
                    secondsCoordinator.mode = .ss
                    secondsCoordinator.startClock(interval: 0.25)
                } else {
                    secondsCoordinator.stop()
                }
            }
            .onChange(of: settings.digitFontOverride) { _ in settings.applyGlobalToggles() }
            .onChange(of: settings.soundEnabled) { _ in settings.applyGlobalToggles() }
            .onChange(of: settings.hapticsEnabled) { _ in settings.applyGlobalToggles() }
        }
    }
}
