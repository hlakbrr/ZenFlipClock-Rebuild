import SwiftUI
import Combine
import QuartzCore
import ObjectiveC

/// 整排协调器 —— 还原自 FUN_100063ef8（SplitFlapRowDrumCoordinator）：
/// 同一排格子不是同时翻，而是按 elapsed 逐格错峰触发——"波浪式"翻页。
/// Timer 负责"发现变化"，DisplayLink 负责"演出变化"，两层解耦。
@MainActor
final class SplitFlapRowDrumCoordinator: ObservableObject {

    enum Mode {
        /// 时:分（4 格，冒号是分隔符不占格）
        case hhmm
        /// 秒（2 格）
        case ss
    }

    /// 一行格子
    @Published var cells: [SplitFlapCellModel]

    /// 检时模式
    var mode: Mode = .hhmm
    /// 每格错峰延迟（秒）
    var stagger: Double = 0.08
    /// 单格翻页时长（秒）
    var flipDuration: Double = 0.22

    private var repeatingTimer: Timer?
    private var lastSecond: Int?

    init(initialText: String) {
        let chars = Array(initialText)
        cells = chars.map { SplitFlapCellModel(initial: String($0)) }
    }

    deinit {
        repeatingTimer?.invalidate()
    }

    /// 秒级业务节拍：重复 Timer 以小间隔醒来 → 取当前时分/秒 → 与上次比对 →
    /// 变了才构造事件时间轴交给 DisplayLink 播放（原版 Counter 里 839 处 Date 使用）。
    func startClock(interval: TimeInterval = 0.25) {
        stop()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTime()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatingTimer = timer
        checkTime()
    }

    func stop() {
        repeatingTimer?.invalidate()
        repeatingTimer = nil
    }

    func checkTime() {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        switch mode {
        case .hhmm:
            guard let h = comps.hour, let m = comps.minute else { return }
            setText(String(format: "%02d:%02d", h, m))
            if let s = comps.second {
                if lastSecond == 59 && s == 0 {
                    FlipSoundPlayer.shared.playWhirr()
                }
                lastSecond = s
            }
        case .ss:
            guard let s = comps.second else { return }
            setText(String(format: "%02d", s))
            lastSecond = s
        }
    }

    /// 设置目标文本；只翻变化了的格，逐格错峰起翻。
    /// 冒号等分隔符不占格子：只取数字字符与格子一一对应。
    func setText(_ text: String) {
        let digits = Array(text.filter { $0.isNumber })
        guard digits.count == cells.count else { return }

        for (i, ch) in digits.enumerated() {
            let cell = cells[i]
            let target = String(ch)
            if cell.displayed == target, cell.flipProgress == nil { continue }
            if cell.flipProgress != nil && cell.next == target { continue }

            let delay = Double(i) * stagger
            if delay == 0 {
                beginFlip(cell: cell, target: target)
            } else {
                // 错峰起翻：每格 delay 递增（音效在起翻瞬间播，不是现在播）
                let cellRef = cell
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    Task { @MainActor in
                        cellRef.next = target
                        self.startCellDriver(cell: cellRef)
                        FlipSoundPlayer.shared.play(mode: .fast)
                    }
                }
            }
        }
    }

    private func beginFlip(cell: SplitFlapCellModel, target: String) {
        cell.next = target
        startCellDriver(cell: cell)
        FlipSoundPlayer.shared.play(mode: .slow)
    }

    /// 用 SplitFlapCellDisplayLinkDriver（FUN_100073450/100073530）驱动单格翻页
    private func startCellDriver(cell: SplitFlapCellModel) {
        guard cell.flipProgress == nil else { return }
        cell.flipProgress = 0
        let duration = flipDuration
        let driver = SplitFlapCellDisplayLinkDriver(
            duration: duration,
            frameCallback: { [weak cell] progress in
                Task { @MainActor in
                    cell?.flipProgress = progress
                }
            },
            completion: { [weak cell] in
                Task { @MainActor in
                    guard let cell = cell else { return }
                    cell.displayed = cell.next
                    cell.flipProgress = nil
                    HapticsManager.shared.flipLanded()
                    FlipSoundPlayer.shared.playLanding()
                }
            })
        driver.start()
        // driver 由闭包持有到 completion 为止；这里以 objc 关联保活，防止提前释放
        objc_setAssociatedObject(cell, &AssociatedKeys.driver, driver, .OBJC_ASSOCIATION_RETAIN)
    }

    private enum AssociatedKeys {
        static var driver: UInt8 = 0
    }
}
