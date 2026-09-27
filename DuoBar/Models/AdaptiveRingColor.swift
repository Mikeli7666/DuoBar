import AppKit
import SwiftUI

enum AdaptiveRingColorRole: String, Equatable {
    case monochrome
    case brightness
    case cpu
    case memory
    case thermal
}

struct AdaptiveRingColorPresentation: Equatable {
    let role: AdaptiveRingColorRole
    let intensity: Double

    var color: Color? {
        guard role != .monochrome else { return nil }
        let base: Color
        switch role {
        case .monochrome: return nil
        case .brightness: base = Color(nsColor: .systemYellow)
        case .cpu: base = .blue
        case .memory: base = .purple
        case .thermal: base = .orange
        }
        return base.opacity(intensity)
    }
}

enum AdaptiveRingColorResolver {
    static func resolve(
        state: AdaptiveRingState,
        decision: PerformanceDecision,
        colorCodingEnabled: Bool
    ) -> AdaptiveRingColorPresentation {
        guard colorCodingEnabled else {
            return AdaptiveRingColorPresentation(role: .monochrome, intensity: 1)
        }

        if case .brightness = state {
            return AdaptiveRingColorPresentation(role: .brightness, intensity: 1)
        }

        guard case .performance(let metric, _) = state,
              metric == decision.activeMetric
        else { return AdaptiveRingColorPresentation(role: .monochrome, intensity: 1) }

        let role: AdaptiveRingColorRole
        switch metric {
        case .cpu: role = .cpu
        case .memory: role = .memory
        case .thermal: role = .thermal
        case .idle: return AdaptiveRingColorPresentation(role: .monochrome, intensity: 1)
        }
        return AdaptiveRingColorPresentation(role: role, intensity: intensity(for: decision.severity))
    }

    static func intensity(for severity: PerformanceSeverity) -> Double {
        switch severity {
        case .idle, .normal: 0.60
        case .elevated: 0.68
        case .serious: 0.82
        case .critical: 1.0
        }
    }
}
