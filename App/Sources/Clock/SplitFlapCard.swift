import SwiftUI
import Combine

/// 单格翻页显示模型：displayed 为当前稳定字符，next 为翻页目标，
/// flipProgress 非 nil 表示正在翻页（0→1，由 SplitFlapCellDisplayLinkDriver 驱动）。
@MainActor
final class SplitFlapCellModel: ObservableObject {
    @Published var displayed: String
    @Published var next: String = ""
    @Published var flipProgress: Double?

    init(initial: String) {
        displayed = initial
    }
}

/// 翻页卡片的半面（上/下），文字垂直居中于整卡、按半面裁切——
/// 翻页钟的字形中线正好压在分界线上。
private struct SplitFlapHalf: View {
    let text: String
    let theme: ClockTheme
    let size: CGSize
    let isTop: Bool
    let fontSize: CGFloat

    var body: some View {
        let half = size.height / 2
        return ZStack {
            LinearGradient(
                gradient: Gradient(colors: isTop
                    ? [theme.cardBackground.opacity(0.82), theme.cardBackground]
                    : [theme.cardBackground, theme.cardBackground.opacity(0.82)]),
                startPoint: .top, endPoint: .bottom)
            Text(text)
                .font(.custom(theme.digitFontName, size: fontSize))
                .foregroundColor(theme.digitColor)
                .frame(width: size.width, height: size.height, alignment: .center)
                .offset(y: isTop ? size.height / 4 : -size.height / 4)
        }
        .frame(width: size.width, height: half)
        .clipped()
    }
}

/// 单格翻页卡片 —— SwiftUI 渲染层。
/// 翻页分两段（progress 0→1）：
///   A 段 0→0.5：上半面（旧字符）绕中线向后折 0→-90°；
///   B 段 0.5→1：下半面翻板（新字符）从 +90° 落回 0° 盖住下静态面。
/// 渲染闭包拿 0→1 的 progress 自己映射到翻板角度（对应反编译里 driver 的 frameCallback）。
struct SplitFlapCard: View {
    @ObservedObject var model: SplitFlapCellModel
    let theme: ClockTheme
    let size: CGSize

    private var fontSize: CGFloat { size.height * 0.78 }

    var body: some View {
        ZStack {
            if let p = model.flipProgress {
                let phaseA = min(p / 0.5, 1)
                let phaseB = max(0, (p - 0.5) / 0.5)
                // 静态上半面：新字符（A 板折走后从后面显露）
                SplitFlapHalf(text: model.next, theme: theme, size: size, isTop: true, fontSize: fontSize)
                // 静态下半面：旧字符（等 B 板落下盖住）
                SplitFlapHalf(text: model.displayed, theme: theme, size: size, isTop: false, fontSize: fontSize)
                // A 段翻板：上半面旧字符向后折
                SplitFlapHalf(text: model.displayed, theme: theme, size: size, isTop: true, fontSize: fontSize)
                    .rotation3DEffect(
                        .degrees(-90 * phaseA),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        anchorZ: 0,
                        perspective: 0.55)
                    .overlay(Color.black.opacity(0.45 * phaseA))
                    .allowsHitTesting(false)
                // B 段翻板：下半面新字符落下
                SplitFlapHalf(text: model.next, theme: theme, size: size, isTop: false, fontSize: fontSize)
                    .rotation3DEffect(
                        .degrees(90 * (1 - phaseB)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        anchorZ: 0,
                        perspective: 0.55)
                    .overlay(Color.black.opacity(0.45 * (1 - phaseB)))
                    .allowsHitTesting(false)
            } else {
                SplitFlapHalf(text: model.displayed, theme: theme, size: size, isTop: true, fontSize: fontSize)
                SplitFlapHalf(text: model.displayed, theme: theme, size: size, isTop: false, fontSize: fontSize)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: size.height * 0.10, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)
    }
}
