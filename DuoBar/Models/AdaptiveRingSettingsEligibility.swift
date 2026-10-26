import Foundation

enum AdaptiveRingSettingsEligibility {
    static func isEligible(for context: DeviceContext) -> Bool {
        context.ringBehavior == .adaptiveRing || context.hasInternalBattery
    }

    #if DEBUG
    static func isEligible(for context: DeviceContext, simulateDesktop: Bool) -> Bool {
        simulateDesktop || isEligible(for: context)
    }
    #endif
}
