import SwiftUI

/// 主题：时钟风格 / 字体 / 颜色。字体名来自对原包 TTF name 表的解析。
/// 数字字体清单（原版设置页可选）：
///   Digtal-ZFC / Bebas Neue / Anton / Cursed Timer ULiL / Pocket Calculator /
///   MatrixType / Staatliches / Pathway Gothic One / Alumni Sans Pinstripe /
///   Roboto / Roboto Mono / Roboto Slab / Barlow / Heebo
enum ClockTheme: String, CaseIterable, Identifiable {
    /// 用户自定义字体覆盖（设置页选择后非空）
    static var fontOverrideName: String?

    case classic
    case dark
    case modern
    case retro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "经典"
        case .dark: return "深色"
        case .modern: return "现代"
        case .retro: return "复古"
        }
    }

    var background: Color {
        switch self {
        case .classic: return Color(red: 0.06, green: 0.06, blue: 0.07)
        case .dark: return Color.black
        case .modern: return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .retro: return Color(red: 0.12, green: 0.08, blue: 0.05)
        }
    }

    var cardBackground: Color {
        switch self {
        case .classic: return Color(red: 0.11, green: 0.11, blue: 0.13)
        case .dark: return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .modern: return Color(red: 0.16, green: 0.16, blue: 0.19)
        case .retro: return Color(red: 0.20, green: 0.13, blue: 0.08)
        }
    }

    var digitColor: Color {
        switch self {
        case .classic: return Color(red: 0.92, green: 0.93, blue: 0.95)
        case .dark: return Color.white
        case .modern: return Color(red: 0.85, green: 0.95, blue: 0.90)
        case .retro: return Color(red: 1.00, green: 0.76, blue: 0.30)
        }
    }

    var digitFontName: String {
        if let override = ClockTheme.fontOverrideName { return override }
        switch self {
        case .classic: return "Digtal-ZFC"
        case .dark: return "Bebas Neue"
        case .modern: return "Roboto Mono Medium"
        case .retro: return "PocketCalculator"
        }
    }
}
