import SwiftUI

/// 设置页：主题 / 声音 / 触感 / 秒显示 / 数字字体（对应原版设置项的最小集）。
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.presentationMode) private var presentationMode

    private let fontOptions: [String] = [
        "",                       // 跟随主题
        "Digtal-ZFC",
        "Bebas Neue",
        "Anton",
        "Cursed Timer ULiL",
        "PocketCalculator",
        "MatrixType-Regular",
        "MatrixType-Bold",
        "Staatliches",
        "Pathway Gothic One",
        "Alumni Sans Pinstripe",
        "Roboto",
        "Roboto Mono Medium",
        "Roboto Slab",
        "Barlow",
        "Heebo",
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("外观")) {
                    Picker("主题", selection: themeBinding) {
                        ForEach(ClockTheme.allCases) { t in
                            HStack {
                                Circle()
                                    .fill(t.background)
                                    .overlay(Circle().strokeBorder(Color.gray.opacity(0.4)))
                                    .overlay(Text("12").font(.custom(t.digitFontName, size: 13)).foregroundColor(t.digitColor))
                                    .frame(width: 34, height: 34)
                                Text(t.displayName)
                            }
                            .tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.inline)

                    Picker("数字字体", selection: fontBinding) {
                        ForEach(fontOptions, id: \.self) { f in
                            Text(f.isEmpty ? "跟随主题" : f).tag(f)
                        }
                    }
                }

                Section(header: Text("显示")) {
                    Toggle("显示秒", isOn: $settings.secondsVisible)
                }

                Section(header: Text("声音与触感")) {
                    Toggle("翻页音效", isOn: $settings.soundEnabled)
                    Toggle("触感反馈", isOn: $settings.hapticsEnabled)
                }

                Section(footer: Text("复刻版 v1.0 · 基于 Zen Flip Clock 4.15.2 反编译资料重建")) {
                    HStack {
                        Spacer()
                        Button("完成") { presentationMode.wrappedValue.dismiss() }
                        Spacer()
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { settings.themeRaw },
            set: {
                settings.themeRaw = $0
                HapticsManager.shared.selectionChanged()
            })
    }

    private var fontBinding: Binding<String> {
        Binding(
            get: { settings.digitFontOverride },
            set: {
                settings.digitFontOverride = $0
                settings.applyGlobalToggles()
            })
    }
}
