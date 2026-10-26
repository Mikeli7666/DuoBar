import Foundation

/// The top-level ring choice for a Mac with an internal battery.
/// This is intentionally independent from Adaptive Ring telemetry and rendering.
enum LaptopRingMode: Equatable, Sendable {
    case battery
    case adaptive
}

/// The supported delay choices for a fully charged, plugged-in MacBook.
/// Settings can persist this typed value in a later phase.
enum LaptopAdaptiveFullChargeDelay: String, CaseIterable, Equatable, Sendable {
    case immediately
    #if DEBUG
    /// Temporary real-hardware QA duration. Do not use for production release.
    case oneMinute
    #endif
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    static let `default`: Self = .fifteenMinutes

    var timeInterval: TimeInterval {
        switch self {
        case .immediately: 0
        #if DEBUG
        case .oneMinute: 60
        #endif
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        }
    }
}

/// Read-only diagnostic state for the future MacBook Battery → Adaptive integration.
struct LaptopRingModeState: Equatable, Sendable {
    let mode: LaptopRingMode
    let sessionStartPercentage: Int?
    let targetPercentage: Int?
    let isWaitingForFullChargeDelay: Bool

    static let battery = LaptopRingModeState(
        mode: .battery,
        sessionStartPercentage: nil,
        targetPercentage: nil,
        isWaitingForFullChargeDelay: false
    )
}
