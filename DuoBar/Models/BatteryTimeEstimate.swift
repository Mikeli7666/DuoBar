import Foundation

/// Time estimate reported by IOPowerSources for the internal battery.
enum BatteryTimeEstimate: Equatable, Sendable {
    /// The system has not produced an estimate yet (it reports -1).
    case calculating
    case toFull(minutes: Int)
    case toEmpty(minutes: Int)
    /// Nothing meaningful to show (fully charged, on hold, or no data).
    case unavailable

    /// - Parameters:
    ///   - timeToFull / timeToEmpty: minutes as reported by IOPS, -1 while calculating.
    static func resolve(
        isCharging: Bool,
        isPluggedIn: Bool,
        isFullyCharged: Bool,
        timeToFull: Int?,
        timeToEmpty: Int?
    ) -> BatteryTimeEstimate {
        if isFullyCharged { return .unavailable }
        if isCharging {
            guard let timeToFull else { return .unavailable }
            return timeToFull > 0 ? .toFull(minutes: timeToFull) : .calculating
        }
        if !isPluggedIn {
            guard let timeToEmpty else { return .unavailable }
            return timeToEmpty > 0 ? .toEmpty(minutes: timeToEmpty) : .calculating
        }
        return .unavailable
    }
}

enum BatteryTimeFormatter {
    /// "45m", "1h", "1h 5m", localised by the system.
    static func duration(minutes: Int, locale: Locale = .current) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(max(0, minutes) * 60)) ?? "\(max(0, minutes))m"
    }
}
