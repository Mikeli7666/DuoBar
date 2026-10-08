import Foundation

/// What the user asked the outer arc to show.
/// `automatic` keeps the existing Battery Ring / Adaptive Ring policy.
enum OuterRingChoice: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case battery
    case brightness
    case processor
    case memory
    case heat

    var id: String { rawValue }

    init(stored value: String?) {
        self = OuterRingChoice(rawValue: value ?? "") ?? .automatic
    }

    var localizationKey: String {
        switch self {
        case .automatic: "Automatic"
        case .battery: "Battery level"
        case .brightness: "Brightness"
        case .processor: "Processor"
        case .memory: "Memory"
        case .heat: "Heat"
        }
    }

    static func automaticAdaptiveRingIsActive(enabled: Bool, systemUsesAdaptiveRing: Bool) -> Bool {
        enabled && systemUsesAdaptiveRing
    }

    var needsTelemetry: Bool {
        switch self {
        case .automatic, .battery: false
        case .brightness, .processor, .memory, .heat: true
        }
    }
}

struct OuterRingSample: Equatable, Sendable {
    var automaticUsesAdaptiveRing: Bool
    var automaticState: AdaptiveRingState
    var cpuLoad: Double?
    var memoryUsed: Double?
    var thermal: PerformanceThermalState
    var brightness: Double?
}

struct OuterRingReading: Equatable, Sendable {
    enum Subject: Equatable, Sendable {
        case battery
        case brightness(Double)
        case processor(Double)
        case memory(Double)
        case heat(Double)
        case unavailable
    }

    let subject: Subject

    var showsAdaptiveArc: Bool {
        if case .battery = subject { return false }
        return true
    }

    var progress: Double {
        switch subject {
        case .battery:
            return 0
        case .brightness(let value), .processor(let value), .memory(let value), .heat(let value):
            return Self.clamp(value)
        case .unavailable:
            return AdaptiveRingVisualTarget.neutralBaseline
        }
    }

    var localizationKey: String {
        switch subject {
        case .battery: "Battery level"
        case .brightness: "Brightness"
        case .processor: "Processor"
        case .memory: "Memory"
        case .heat: "Heat"
        case .unavailable: "Unavailable"
        }
    }

    var symbolName: String {
        switch subject {
        case .battery: "battery.100"
        case .brightness: "sun.max.fill"
        case .processor: "cpu"
        case .memory: "memorychip"
        case .heat: "thermometer.medium"
        case .unavailable: "circle.dashed"
        }
    }

    var adaptiveState: AdaptiveRingState {
        switch subject {
        case .battery, .unavailable:
            return .neutral
        case .brightness(let value):
            return .brightness(Self.clamp(value))
        case .processor(let value):
            return .performance(metric: .cpu, value: Self.clamp(value))
        case .memory(let value):
            return .performance(metric: .memory, value: Self.clamp(value))
        case .heat(let value):
            return .performance(metric: .thermal, value: Self.clamp(value))
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

enum OuterRingResolver {
    static func resolve(choice: OuterRingChoice, sample: OuterRingSample) -> OuterRingReading {
        switch choice {
        case .automatic:
            guard sample.automaticUsesAdaptiveRing else {
                return OuterRingReading(subject: .battery)
            }
            return reading(for: sample.automaticState)
        case .battery:
            return OuterRingReading(subject: .battery)
        case .brightness:
            guard let value = sample.brightness else {
                return OuterRingReading(subject: .unavailable)
            }
            return OuterRingReading(subject: .brightness(value))
        case .processor:
            return OuterRingReading(subject: .processor(sample.cpuLoad ?? 0))
        case .memory:
            return OuterRingReading(subject: .memory(sample.memoryUsed ?? 0))
        case .heat:
            return OuterRingReading(subject: .heat(heatProgress(sample.thermal)))
        }
    }

    static func heatProgress(_ state: PerformanceThermalState) -> Double {
        switch state {
        case .nominal: 0.12
        case .fair: 0.55
        case .serious: 0.82
        case .critical: 1
        }
    }

    private static func reading(for state: AdaptiveRingState) -> OuterRingReading {
        switch state {
        case .neutral:
            return OuterRingReading(subject: .unavailable)
        case .brightness(let value):
            return OuterRingReading(subject: .brightness(value))
        case .performance(let metric, let value):
            switch metric {
            case .idle:
                return OuterRingReading(subject: .unavailable)
            case .cpu:
                return OuterRingReading(subject: .processor(value))
            case .memory:
                return OuterRingReading(subject: .memory(value))
            case .thermal:
                return OuterRingReading(subject: .heat(value))
            }
        }
    }
}
