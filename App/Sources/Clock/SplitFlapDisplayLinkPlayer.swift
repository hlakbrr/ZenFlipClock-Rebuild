import Foundation
import QuartzCore

/// 事件时间轴播放器 —— 还原自 FUN_10005bf70（SplitFlapDisplayLinkPlayer::tick）。
/// 一次翻页 = 一小段事件时间轴：按事件表触发"翻页+声音"事件，
/// 渲染按"距下个事件的时长"平滑推进，触发与渲染解耦。
final class SplitFlapDisplayLinkPlayer: NSObject {

    struct Event {
        let time: Double
        let str1: String
        let str2: String
    }

    typealias FireCallback = (Double, String, String) -> Void
    typealias RenderCallback = (Double) -> Void
    typealias Completion = () -> Void

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0

    // 事件数组（反编译里 stride 0x18: {time, str1, str2}）
    private var events: [Event] = []
    private var currentIndex: Int = 0
    private var totalDuration: Double = 0
    private var lastFiredTime: CFTimeInterval = 0

    // self+0x70 提前量；+0x78 最小触发间隔
    var leadTime: Double = 0.05
    var minFireGap: Double = 0.02

    var fireCallback: FireCallback?
    var renderCallback: RenderCallback?
    var completion: Completion?

    deinit {
        displayLink?.invalidate()
    }

    func setEvents(_ events: [Event]) {
        self.events = events
        currentIndex = 0
        totalDuration = events.map { $0.time }.max() ?? 0
    }

    func play() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        startTime = CACurrentMediaTime()
        lastFiredTime = .zero
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// FUN_10005bf70
    @objc private func tick() {
        guard displayLink != nil else { return }
        let elapsed = CACurrentMediaTime() - startTime

        // ① 按时间点触发事件（翻页指令/声音）
        if currentIndex < events.count {
            let event = events[currentIndex]
            if event.time <= elapsed + leadTime,
               (CACurrentMediaTime() - lastFiredTime) >= minFireGap {
                fireCallback?(event.time, event.str1, event.str2)
                FlipSoundPlayer.shared.playForFrame(throttled: false)
                lastFiredTime = CACurrentMediaTime()
                currentIndex += 1
            }
        }

        // ② 渲染回调：进度 = 距下一个事件的时长（夹住）
        if currentIndex < events.count {
            let t = max(0, min(elapsed, max(0, events[currentIndex].time - leadTime)))
            renderCallback?(t)
        } else {
            renderCallback?(elapsed)
        }

        // ③ 全部事件放完且超过总时长 → 收摊
        if currentIndex >= events.count, elapsed + leadTime >= totalDuration {
            displayLink?.invalidate()
            displayLink = nil
            completion?()
        }
    }

    // MARK: - 通用 NSTimer 封装 —— 还原自 FUN_100299468（不重复）/ FUN_100299588（重复）

    @discardableResult
    static func scheduleOnce(after interval: TimeInterval, _ block: @escaping () -> Void) -> Timer {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in block() }
    }

    @discardableResult
    static func scheduleRepeating(every interval: TimeInterval, _ block: @escaping () -> Void) -> Timer {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in block() }
    }
}
