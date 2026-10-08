import Foundation

enum DuoCenterState: Hashable {
    case wifi(WiFiSignalLevel)
    case ethernet
    case offline
    case other
    case unavailable
    case airPodsPro
    case airPodsMax
    case airPods
    case headphones
    case audioDevice
    case adaptiveBrightness
    case performanceCPU
    case performanceMemory
    case performanceThermal
    case adaptiveEntry
}

enum DuoSemanticFeedback: Equatable {
    case none
    case charging
    case lowBattery
    case audioConnected
}

enum DuoPersistentRingMode: Equatable {
    case battery
    case adaptive
}

struct DuoPersistentRingPresentation: Equatable {
    let mode: DuoPersistentRingMode
    let progress: Double
    let opacity: Double
    let batteryPresentation: BatteryRingPresentation

    static func battery(
        _ battery: BatteryStatus,
        colorCodingEnabled: Bool
    ) -> DuoPersistentRingPresentation {
        let progress: Double
        if battery.isFullyCharged {
            progress = 1
        } else if battery.isAvailable, let percentage = battery.percentage {
            progress = min(max(Double(percentage) / 100, 0), 1)
        } else {
            progress = 1
        }
        return DuoPersistentRingPresentation(
            mode: .battery,
            progress: progress,
            opacity: battery.isAvailable ? 1 : 0.22,
            batteryPresentation: BatteryRingPresentation.resolve(
                battery: battery,
                colorCodingEnabled: colorCodingEnabled
            )
        )
    }

    static func adaptive(progress: Double) -> DuoPersistentRingPresentation {
        DuoPersistentRingPresentation(
            mode: .adaptive,
            progress: min(max(progress, 0), 1),
            opacity: 1,
            batteryPresentation: BatteryRingPresentation(
                boltPlacement: .none,
                colorRole: .monochrome
            )
        )
    }
}

enum DuoPersistentRingPresentationResolver {
    static func resolve(
        mode: DuoPersistentRingMode,
        battery: BatteryStatus,
        adaptiveProgress: Double,
        batteryColorCodingEnabled: Bool
    ) -> DuoPersistentRingPresentation {
        switch mode {
        case .battery:
            return .battery(battery, colorCodingEnabled: batteryColorCodingEnabled)
        case .adaptive:
            return .adaptive(progress: adaptiveProgress)
        }
    }
}

struct DuoGlyphState: Equatable {
    let ringPresentation: DuoPersistentRingPresentation
    let batteryProgress: Double
    let batteryArcOpacity: Double
    let isCharging: Bool
    let batteryPresentation: BatteryRingPresentation
    let centerState: DuoCenterState
    let volumeActiveDotCount: Int?
    let feedback: DuoSemanticFeedback
    let audioEventID: UUID?

    init(
        status: SystemStatus,
        presentation: StatusPresentation = .normal,
        ringPresentation: DuoPersistentRingPresentation? = nil,
        centerStateOverride: DuoCenterState? = nil,
        batteryColorCodingEnabled: Bool = false
    ) {
        let battery = status.battery
        let resolvedRing = ringPresentation ?? .battery(
            battery,
            colorCodingEnabled: batteryColorCodingEnabled
        )
        self.ringPresentation = resolvedRing
        batteryProgress = resolvedRing.progress
        batteryArcOpacity = resolvedRing.opacity
        isCharging = resolvedRing.mode == .battery
            && battery.isAvailable
            && battery.isCharging
            && !battery.isFullyCharged
        batteryPresentation = resolvedRing.batteryPresentation
        volumeActiveDotCount = status.audio.volume.activeDotCount

        let normalCenter = centerStateOverride ?? Self.networkCenter(for: status.network)
        guard let event = presentation.event else {
            centerState = normalCenter
            feedback = .none
            audioEventID = nil
            return
        }

        switch event.kind {
        case .audioDeviceConnected(let device):
            switch device.temporaryConnectionGlyph {
            case .airPodsPro: centerState = .airPodsPro
            case .airPodsMax: centerState = .airPodsMax
            case .airPods: centerState = .airPods
            case .headphones: centerState = .headphones
            case .audioDevice: centerState = .audioDevice
            }
            feedback = .audioConnected
            audioEventID = event.id
        case .charging:
            centerState = normalCenter
            feedback = .charging
            audioEventID = nil
        case .lowBattery:
            centerState = normalCenter
            feedback = .lowBattery
            audioEventID = nil
        case .networkDisconnected:
            centerState = .offline
            feedback = .none
            audioEventID = nil
        }
    }

    private static func networkCenter(for network: NetworkStatus) -> DuoCenterState {
        guard network.isAvailable else { return .unavailable }
        guard network.isConnected else { return .offline }

        switch network.transport {
        case .wifi:
            return .wifi(network.wifiSignalLevel)
        case .ethernet:
            return .ethernet
        case .other:
            return .other
        case .none:
            return .offline
        }
    }
}

/// What the outer arc means right now, in a form the menu bar and the popover can both show.
enum AdaptiveRingCue {
    static func centerState(for source: AdaptiveRingSourceIdentity) -> DuoCenterState? {
        switch source {
        case .neutral: nil
        case .brightness: .adaptiveBrightness
        case .cpu: .performanceCPU
        case .memory: .performanceMemory
        case .thermal: .performanceThermal
        }
    }

    static func localizationKey(usesAdaptiveRing: Bool, state: AdaptiveRingState) -> String {
        guard usesAdaptiveRing else { return "Battery level" }
        switch AdaptiveRingSourceIdentity(state: state) {
        case .neutral: return "Unavailable"
        case .brightness: return "Brightness"
        case .cpu: return "Processor"
        case .memory: return "Memory"
        case .thermal: return "Heat"
        }
    }

    static func symbolName(usesAdaptiveRing: Bool, state: AdaptiveRingState) -> String {
        guard usesAdaptiveRing else { return "battery.100" }
        switch AdaptiveRingSourceIdentity(state: state) {
        case .neutral: return "circle.dashed"
        case .brightness: return "sun.max.fill"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .thermal: return "thermometer.medium"
        }
    }
}

extension OuterRingReading {
    var centerState: DuoCenterState? {
        switch subject {
        case .battery, .unavailable: nil
        case .brightness: .adaptiveBrightness
        case .processor: .performanceCPU
        case .memory: .performanceMemory
        case .heat: .performanceThermal
        }
    }
}
