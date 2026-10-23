import CoreGraphics
import Foundation

struct BatteryChargingAnimationSnapshot: Equatable {
    let boltProgress: Double
    let trackProgress: Double
    let colorMix: Double
}

enum BatteryChargingAnimationProfile {
    // Measured at the source recording's 60 fps presentation cadence.
    static let sourceFrameRate = 60.0
    static let boltEntranceFrameCount = 26
    static let trackEntranceFrameCount = 18
    static let colorDelayFrameCount = 42
    static let colorTransitionFrameCount = 19
    static let exitFrameCount = 22

    static let boltEntranceDuration = Double(boltEntranceFrameCount) / sourceFrameRate
    static let trackEntranceDuration = Double(trackEntranceFrameCount) / sourceFrameRate
    static let colorDelay = Double(colorDelayFrameCount) / sourceFrameRate
    static let colorTransitionDuration = Double(colorTransitionFrameCount) / sourceFrameRate
    static let exitDuration = Double(exitFrameCount) / sourceFrameRate
    static let entranceDuration = colorDelay + colorTransitionDuration

    // The stable reference bolt measured 33 x 50 px against a 230 px outer ring.
    // SF Symbols' bold bolt has a measured rendered-height/font-size ratio of 1.16.
    static let boltFontSizeRatio: CGFloat = (50 / 1.16) / 230
    static let boltOpacity = 1.0
    // Re-measured from the 60 fps reference recording: the bolt's ink box is centred on the
    // ring line (3.5 px inside the path radius, 0.5 px left of the ring centre at 230 px).
    static let boltRadialOffsetRatio: CGFloat = -3.5 / 230
    static let boltHorizontalOffsetRatio: CGFloat = -0.5 / 230

    static let inactiveTrackOpacity = 0.24

    // Bolt outline: the ring (track and fill) is knocked out around the bolt silhouette
    // grown by 14.5 px (at 230 px). The cut opens 12 frames after the bolt starts, over 5
    // frames, and closes in 5 frames when the bolt leaves.
    static let boltGapDilationRatio: CGFloat = 14.5 / 230
    static let boltGapDelayFrameCount = 12
    static let boltGapEntranceFrameCount = 5
    static let boltGapExitFrameCount = 5
    static let boltGapDelay = Double(boltGapDelayFrameCount) / sourceFrameRate
    static let boltGapEntranceDuration = Double(boltGapEntranceFrameCount) / sourceFrameRate
    static let boltGapExitDuration = Double(boltGapExitFrameCount) / sourceFrameRate

    // When the ring reaches 100% with the charger still connected, the bolt eases to about
    // half opacity over 33 frames (cubic-bezier 0.2, 0.3, 0.2, 1) and stays there.
    static let fullChargeBoltOpacity = 0.52
    static let fullChargeDimFrameCount = 33
    static let fullChargeDimDuration = Double(fullChargeDimFrameCount) / sourceFrameRate

    // Dropping below the low-battery threshold fades the ring from white to red over 23 frames.
    static let lowBatteryColorFadeFrameCount = 23
    static let lowBatteryColorFadeDuration = Double(lowBatteryColorFadeFrameCount) / sourceFrameRate

    static func entranceSnapshot(elapsed: TimeInterval) -> BatteryChargingAnimationSnapshot {
        let boltTime = clamped(elapsed / boltEntranceDuration)
        let trackTime = clamped(elapsed / trackEntranceDuration)
        let colorTime = clamped((elapsed - colorDelay) / colorTransitionDuration)
        return BatteryChargingAnimationSnapshot(
            boltProgress: cubicEaseOut(boltTime),
            trackProgress: cubicEaseOut(trackTime),
            colorMix: cubicEaseOut(colorTime)
        )
    }

    static func exitSnapshot(elapsed: TimeInterval) -> BatteryChargingAnimationSnapshot {
        let progress = smootherstep(clamped(elapsed / exitDuration))
        return BatteryChargingAnimationSnapshot(
            boltProgress: 1 - progress,
            trackProgress: 1 - progress,
            colorMix: 1 - progress
        )
    }

    static func resolvedSnapshot(
        showsBolt: Bool,
        usesChargingColor: Bool,
        reduceMotion: Bool
    ) -> BatteryChargingAnimationSnapshot {
        if reduceMotion {
            return BatteryChargingAnimationSnapshot(
                boltProgress: showsBolt ? 1 : 0,
                trackProgress: showsBolt ? 1 : 0,
                colorMix: usesChargingColor ? 1 : 0
            )
        }
        return BatteryChargingAnimationSnapshot(
            boltProgress: showsBolt ? 1 : 0,
            trackProgress: showsBolt ? 1 : 0,
            colorMix: usesChargingColor ? 1 : 0
        )
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func cubicEaseOut(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    private static func smootherstep(_ value: Double) -> Double {
        value * value * value * (value * (value * 6 - 15) + 10)
    }
}
