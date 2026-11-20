import Foundation
import QuartzCore

/// 单格翻页动画驱动器 —— 还原自 FUN_100073450（CADisplayLink 创建）与 FUN_100073530（tick）。
/// 设计要点（来自反编译结论）：
/// - CADisplayLink 硬编码 60fps，主 RunLoop common 模式；
/// - 进度 = (now - startTime) / duration 线性归一化，不存"当前角度"；
/// - progress >= 1 时立即 invalidate（省电关键）并回调 completion。
final class SplitFlapCellDisplayLinkDriver: NSObject {

    typealias FrameCallback = (Double) -> Void
    typealias Completion = () -> Void

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: Double = 0
    private var frameCallback: FrameCallback?
    private var completion: Completion?

    init(duration: Double, frameCallback: @escaping FrameCallback, completion: @escaping Completion) {
        self.duration = duration
        self.frameCallback = frameCallback
        self.completion = completion
        super.init()
    }

    deinit {
        displayLink?.invalidate()
    }

    /// FUN_100073450：创建帧循环
    func start() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        // 原版 preferredFramesPerSecond = 0x3c (60)。ProMotion 机型锁 60：
        // preferredFrameRateRange 是 iOS 15+ 的 CADisplayLink API（目标系统恰好 15.0），
        // 而 preferredFramesPerSecond 属性本身 iOS 10 起可用。
        link.preferredFramesPerSecond = 60
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60, maximum: 60, preferred: 60)
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
        startTime = CACurrentMediaTime()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// FUN_100073530：每帧逻辑
    @objc private func tick() {
        guard displayLink != nil else { return }
        var progress = (CACurrentMediaTime() - startTime) / max(duration, 1e-9)
        progress = min(max(progress, 0), 1)
        frameCallback?(progress)
        if progress >= 1 {
            displayLink?.invalidate()
            displayLink = nil
            completion?()
        }
    }
}
