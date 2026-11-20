# Zen Flip Clock（复刻版）

> 基于 [Zen Flip Clock](https://apps.apple.com/app/id1294340101) 4.15.2 解密二进制的反编译资料，
> 重建的可编译 SwiftUI 工程。仅用于原作者（本人）的源码回归研究。

## 项目结构

```
project.yml                 # XcodeGen 工程定义（CI 上生成 .xcodeproj）
App/
  Sources/
    Clock/
      SplitFlapCellDisplayLinkDriver.swift   # 还原 FUN_100073450 / FUN_100073530（单格 60fps 帧驱动）
      SplitFlapDisplayLinkPlayer.swift       # 还原 FUN_10005bf70（事件时间轴播放器）+ FUN_100299468/59（Timer 封装）
      SplitFlapRowDrumCoordinator.swift      # 还原 FUN_100063ef8（整排错峰协调 + 秒级 Timer 检时）
      SplitFlapCard.swift                    # SwiftUI 翻页卡片渲染（两段式 3D 翻板）
      FlipSoundPlayer.swift                  # 还原 FUN_1000442d4 / FUN_1000446e4（声音池 + 双档节流）
    Pomodoro/PomodoroView.swift              # 番茄钟（复用同一套 SplitFlap 演出）
    Settings/SettingsView.swift              # 设置页
    Theme/
      ClockTheme.swift                       # 主题与数字字体（字体名来自原包 TTF name 表解析）
      HapticsManager.swift                   # 触感（原版 41 处调用的管理器）
    ZenFlipClockApp.swift                    # 入口 + 用户偏好
  Resources/               # 从原 ipa 提取的资源（flap.mp3、全套翻页音、16 款数字字体、图标）
.github/workflows/build.yml                  # GitHub Actions：云端 xcodebuild 出免签 ipa
```

## 还原要点（对照反编译结论）

| 原版行为 | 参数来源 | 本工程位置 |
|---|---|---|
| CADisplayLink 硬编码 60fps、common 模式、播完即 invalidate | FUN_100073450/100073530 | SplitFlapCellDisplayLinkDriver |
| 进度 = (now-start)/duration 线性归一化 | 同上 | 同上 |
| 事件时间轴：触发与渲染解耦，leadTime/minGap | FUN_10005bf70 | SplitFlapDisplayLinkPlayer |
| 整排错峰"波浪式"翻页 | FUN_100063ef8 | SplitFlapRowDrumCoordinator.stagger |
| 声音池轮播 + 慢 0.05s / 快 0.06s 节流 | FUN_1000446e4 | FlipSoundPlayer |
| 慢速档 vol 0.16 / rate 2.35，快速档 vol 0.128 / rate 1.0 | float 常量 0x3e23d70a 等 | FlipSoundPlayer |
| AVAudioSession .playback + .mixWithOthers，Bundle 里的 flap.mp3 | FUN_1000442d4 | FlipSoundPlayer.prepare |
| Timer 发现变化 / DisplayLink 演出变化 | Counter（839 处 Date） | 各 Coordinator.startClock |

> 注：冒号是分隔符不占翻板格（原版 4 卡布局同理），Coordinator.setText 只取数字字符映射格子。

## 编译（GitHub Actions）

push 到 GitHub 后 Actions 自动构建，产出的 **免签名 ipa** 在 artifact 里：

1. GitHub 新建仓库，push 本目录全部内容
2. Actions 页等 `Build unsigned ipa` 跑完（约 3-8 分钟）
3. 下载 artifact `ZenFlipClock-ipa`，解压得 `.ipa`

打 tag（如 `v1.0.0`）会额外发布到 GitHub Releases。

## 安装（TrollStore）

1. TrollStore → Apps → Install IPA → 选上面下载的 ipa
2. 完成。免签名包，无需任何证书

> TrollStore 要求：iOS 14.0–16.6.1 / 17.0（视设备与 TrollStore 版本）。

## 故障排查（CI 编译失败时）

1. 打开失败的 Actions 运行页，先看红色步骤名：
   - `Install XcodeGen` / `Generate Xcode project` 挂了 → project.yml 问题，把该步日志发出来
   - `Build (unsigned, device)` 挂了 → Swift 编译错误，下载 artifact 里的 **build-log**，搜 `error:` 行
   - `Package ipa` / `Upload artifact` 挂了 → 打包问题（理论上已加固），把日志发出来
2. 把 `error:` 开头的几行贴给协作方（或整个 build-log），修复通常是单点小改
3. 本地复现（有 Mac 时）：`xcodegen generate` 后用 Xcode 打开直接看报错位置

## 本地编译（需要 macOS + Xcode）

```bash
brew install xcodegen
xcodegen generate
open ZenFlipClock.xcodeproj   # 选 App scheme，真机/模拟器运行
```

## 路线图

- [x] MVP：翻页时钟 + 动画 + 声音 + 触感 + 主题/字体设置 + 番茄钟
- [ ] 时钟墙（ClockWall）多时钟布局
- [ ] 中式时辰显示（SimplifiedHours/TraditionalHours.plist 已在原包中确认）
- [ ] 更换翻页音效（原包 7 种 flip_sound wav 已带齐，可直接接入设置页）
- [ ] Widget（原包含 ZFCWidgetExtension.appex）
- [ ] 整点报时（cabin/circular_gear/cuckoo 等音效已带齐）
- [ ] Siri 快捷指令、内购（RevenueCat）——按需决定是否复刻
