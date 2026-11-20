import Foundation
import AVFoundation
import QuartzCore

/// 翻页声音引擎 —— 还原自 FUN_1000442d4（会话+资源加载）与 FUN_1000446e4（触发/节流/轮播）。
///
/// 三个设计（反编译结论）：
/// 1. AVAudioSession .playback + .mixWithOthers；
/// 2. AVAudioPlayer 池轮播：预建 N 个轮流用，currentTime=0 重播，零重建开销、可叠音；
/// 3. 双档节流：快速档最小间隔 0.06s，慢速档 0.05s；
///    慢速档 volume 0.16 / rate 2.35，快速档 volume 0.128 / rate 1.0
///    （float 常量 0x3e23d70a / 0x3e051eb8 / 0x3f800000 / 0x40166666）。
final class FlipSoundPlayer {

    enum Mode {
        case slow   // 单翻：更沉
        case fast   // 连续快翻：更密更高
    }

    static let shared = FlipSoundPlayer()

    /// 总开关（设置页）
    var isEnabled: Bool = true {
        didSet {
            if !isEnabled { players.forEach { $0.pause() } }
        }
    }

    // 调参常量（与反编译值一一对应）
    private let slowMinGap: Double = 0.05
    private let fastMinGap: Double = 0.06
    private let slowVolume: Float = 0.16
    private let fastVolume: Float = 0.128
    private let slowRate: Float = 2.35
    private let fastRate: Float = 1.0

    private var players: [AVAudioPlayer] = []
    private var nextPlayerIndex: Int = 0
    private var sessionReady = false

    private var lastSlowTime: CFTimeInterval = 0
    private var lastFastTime: CFTimeInterval = 0
    private var lastWhirrPlayTime: CFTimeInterval = 0
    private var lastLandingPlayTime: CFTimeInterval = 0

    private init() {}

    /// FUN_1000442d4：会话 + 资源加载
    func prepare() {
        guard !sessionReady else { return }
        sessionReady = true
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("[FlipSoundPlayer] AVAudioSession error: \(error)")
        }
        guard let url = Bundle.main.url(forResource: "flap", withExtension: "mp3") else {
            NSLog("[FlipSoundPlayer] flap.mp3 not found in bundle")
            return
        }
        players.removeAll()
        for _ in 0..<6 {
            if let p = try? AVAudioPlayer(contentsOf: url) {
                p.enableRate = true
                p.prepareToPlay()
                players.append(p)
            }
        }
    }

    /// FUN_1000446e4 前半：节流
    /// FUN_1000446e4 尾部：池轮播
    func play(mode: Mode = .slow) {
        guard isEnabled else { return }
        prepare()
        guard !players.isEmpty else { return }

        let now = CACurrentMediaTime()
        switch mode {
        case .fast:
            if now - lastFastTime < fastMinGap { return }
            lastFastTime = now
        case .slow:
            if now - lastSlowTime < slowMinGap { return }
            lastSlowTime = now
        }

        let player = players[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        player.volume = (mode == .slow) ? slowVolume : fastVolume
        player.rate = (mode == .slow) ? slowRate : fastRate
        player.currentTime = 0
        player.play()
    }

    /// 每个动画事件都带一声（由 SplitFlapDisplayLinkPlayer.tick 触发）
    func playForFrame(throttled: Bool) {
        if throttled {
            play(mode: .fast)
        } else {
            play(mode: .slow)
        }
    }

    /// 翻页音分"滚动的 whirr"和"落定的 landing"两类，各自独立节流
    /// （元数据里的 lastWhirrPlayTime / lastLandingPlayTime）
    func playWhirr(minGap: Double = 0.08) {
        guard isEnabled else { return }
        prepare()
        guard !players.isEmpty else { return }
        let now = CACurrentMediaTime()
        guard now - lastWhirrPlayTime >= minGap else { return }
        lastWhirrPlayTime = now
        playUnthrottled(volume: fastVolume, rate: fastRate)
    }

    func playLanding(minGap: Double = 0.08) {
        guard isEnabled else { return }
        prepare()
        guard !players.isEmpty else { return }
        let now = CACurrentMediaTime()
        guard now - lastLandingPlayTime >= minGap else { return }
        lastLandingPlayTime = now
        playUnthrottled(volume: slowVolume, rate: slowRate)
    }

    private func playUnthrottled(volume: Float, rate: Float) {
        let player = players[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        player.volume = volume
        player.rate = rate
        player.currentTime = 0
        player.play()
    }
}
