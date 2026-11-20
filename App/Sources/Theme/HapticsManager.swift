import UIKit
import CoreHaptics

/// 触感管理器 —— 原版 HapticsManager 在二进制中有 41 处调用（翻页/交互震动）。
final class HapticsManager {

    static let shared = HapticsManager()

    /// 总开关（设置页）
    var isEnabled: Bool = true

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    private init() {}

    /// 翻页落定时的轻震
    func flipLanded() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// 交互确认
    func tap() {
        mediumImpact.impactOccurred()
    }

    /// 选项切换
    func selectionChanged() {
        selectionFeedback.selectionChanged()
    }
}
