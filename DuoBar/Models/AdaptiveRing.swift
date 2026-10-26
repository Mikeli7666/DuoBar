import Foundation

enum AdaptiveRingState: Equatable, Sendable {
    case brightness(Double)
    case neutral
    case performance(metric: PerformanceMetric, value: Double)

    var normalizedRingValue: Double? {
        switch self {
        case .brightness(let value), .performance(_, let value): value
        case .neutral: nil
        }
    }

    var diagnosticLabel: String {
        switch self {
        case .brightness: "Brightness"
        case .neutral: "Neutral"
        case .performance(let metric, _): "Performance · \(metric.rawValue.capitalized)"
        }
    }
}

/// The user-visible identity of the currently active Adaptive source. Values
/// are intentionally independent of their changing normalized ring progress.
enum AdaptiveRingSourceIdentity: Hashable, Sendable {
    case neutral
    case brightness
    case cpu
    case memory
    case thermal

    init(state: AdaptiveRingState) {
        switch state {
        case .neutral:
            self = .neutral
        case .brightness:
            self = .brightness
        case let .performance(metric, _):
            switch metric {
            case .idle: self = .neutral
            case .cpu: self = .cpu
            case .memory: self = .memory
            case .thermal: self = .thermal
            }
        }
    }
}

struct AdaptiveRingCoordinator: Sendable {
    func resolve(
        brightness _: DisplayBrightnessSnapshot,
        performance: PerformanceDecision,
        at _: TimeInterval
    ) -> AdaptiveRingState {
        if performance.activeMetric != .idle {
            return .performance(
                metric: performance.activeMetric,
                value: clamp(performance.normalizedRingValue)
            )
        }

        return .neutral
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

enum AdaptiveRingTransitionKind: Equatable, Sendable {
    case none
    case baselineUpdate
    case performanceTakeover
    case performanceValueUpdate
    case performanceMetricChange
    case baselineRelease
}

struct AdaptiveRingPresentationTransition: Equatable, Sendable {
    let kind: AdaptiveRingTransitionKind
    let duration: TimeInterval

    static let none = AdaptiveRingPresentationTransition(kind: .none, duration: 0)

    func effectiveDuration(animationsEnabled: Bool, reduceMotion: Bool) -> TimeInterval {
        animationsEnabled && !reduceMotion ? duration : 0
    }
}

enum AdaptiveRingVisualMeaning: Equatable, Sendable {
    case neutral
    case brightness
    case performance(PerformanceMetric)
}

struct AdaptiveRingVisualTarget: Equatable, Sendable {
    static let neutralBaseline = 0.25

    let meaning: AdaptiveRingVisualMeaning
    let progress: Double

    init(state: AdaptiveRingState) {
        switch state {
        case .neutral:
            meaning = .neutral
            progress = Self.neutralBaseline
        case .brightness(let value):
            meaning = .brightness
            progress = Self.clamp(value)
        case .performance(let metric, let value):
            meaning = .performance(metric)
            progress = Self.clamp(value)
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct AdaptiveRingPresentationState: Equatable, Sendable {
    private(set) var adaptiveState: AdaptiveRingState
    private(set) var displayedProgress: Double

    init(state: AdaptiveRingState = .neutral) {
        adaptiveState = state
        displayedProgress = AdaptiveRingVisualTarget(state: state).progress
    }

    mutating func synchronize(to state: AdaptiveRingState) {
        adaptiveState = state
        displayedProgress = AdaptiveRingVisualTarget(state: state).progress
    }

    mutating func retarget(to state: AdaptiveRingState) -> AdaptiveRingPresentationTransition {
        let transition = AdaptiveRingPresentation.transition(from: adaptiveState, to: state)
        guard transition.kind != .none else { return .none }
        adaptiveState = state
        displayedProgress = AdaptiveRingVisualTarget(state: state).progress
        return transition
    }
}

enum AdaptiveRingPresentation {
    static let valueTolerance = 0.005

    static func transition(
        from oldState: AdaptiveRingState,
        to newState: AdaptiveRingState
    ) -> AdaptiveRingPresentationTransition {
        guard isMeaningfullyDifferent(oldState, newState) else { return .none }

        switch (oldState, newState) {
        case (.performance, .brightness), (.performance, .neutral):
            return AdaptiveRingPresentationTransition(kind: .baselineRelease, duration: 0.60)
        case (.brightness, .performance), (.neutral, .performance):
            return AdaptiveRingPresentationTransition(kind: .performanceTakeover, duration: 0.50)
        case (.performance(let oldMetric, _), .performance(let newMetric, _)):
            if oldMetric == newMetric {
                return AdaptiveRingPresentationTransition(kind: .performanceValueUpdate, duration: 0.40)
            }
            return AdaptiveRingPresentationTransition(kind: .performanceMetricChange, duration: 0.45)
        case (.brightness, .brightness), (.brightness, .neutral), (.neutral, .brightness):
            return AdaptiveRingPresentationTransition(kind: .baselineUpdate, duration: 0.40)
        case (.neutral, .neutral):
            return .none
        }
    }

    static func isMeaningfullyDifferent(
        _ oldState: AdaptiveRingState,
        _ newState: AdaptiveRingState
    ) -> Bool {
        switch (oldState, newState) {
        case (.neutral, .neutral):
            return false
        case (.brightness(let old), .brightness(let new)):
            return abs(old - new) >= valueTolerance
        case (.performance(let oldMetric, let old), .performance(let newMetric, let new)):
            return oldMetric != newMetric || abs(old - new) >= valueTolerance
        default:
            return true
        }
    }

    static func metricToIdentify(
        from oldMetric: PerformanceMetric,
        to newMetric: PerformanceMetric,
        hasHigherPriorityEvent: Bool
    ) -> PerformanceMetric? {
        guard !hasHigherPriorityEvent,
              newMetric != .idle,
              newMetric != oldMetric
        else { return nil }
        return newMetric
    }
}

enum AdaptiveEntryCenterPolicy {
    static let duration: TimeInterval = 1.35

    static func shouldRequest(from oldMode: LaptopRingMode, to newMode: LaptopRingMode) -> Bool {
        oldMode == .battery && newMode == .adaptive
    }

    static func allows(over event: StatusEvent?) -> Bool {
        guard let event else { return true }
        if case .charging = event.kind { return true }
        return false
    }
}

enum AdaptiveSourcePresentationPolicy {
    static let duration: TimeInterval = 1.35

    static func shouldPresent(
        from previous: AdaptiveRingSourceIdentity,
        to current: AdaptiveRingSourceIdentity,
        isAdaptiveEntryPresenting: Bool,
        hasHigherPriorityEvent: Bool
    ) -> Bool {
        previous != current
            && current != .neutral
            && !isAdaptiveEntryPresenting
            && !hasHigherPriorityEvent
    }
}

enum AdaptiveRingDiagnosticFormatter {
    static func visualTarget(_ state: AdaptiveRingState) -> String {
        let target = AdaptiveRingVisualTarget(state: state)
        switch target.meaning {
        case .neutral:
            return "Neutral baseline · \(percentage(target.progress))"
        case .brightness:
            return "Brightness · \(percentage(target.progress))"
        case .performance(let metric):
            return "\(metric.rawValue.capitalized) · \(percentage(target.progress))"
        }
    }

    private static func percentage(_ value: Double) -> String {
        String(format: "%.1f%%", locale: Locale(identifier: "en_US_POSIX"), value * 100)
    }
}
