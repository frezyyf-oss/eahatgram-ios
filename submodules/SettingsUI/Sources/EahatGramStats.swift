import Foundation

public final class EahatGramStats {
    public static let shared = EahatGramStats()

    private static let keyTotal = "eahat_total_sent"
    private static let keyDaily = "eahat_daily"

    private let defaults = UserDefaults.standard

    public var totalSent: Int {
        return defaults.integer(forKey: Self.keyTotal)
    }

    public var sentToday: Int {
        return daily[todayKey()] ?? 0
    }

    public var sentThisWeek: Int {
        return sumDays(count: 7)
    }

    public var sentThisMonth: Int {
        return sumDays(count: 30)
    }

    // Returns last N days as [(shortLabel, count)], oldest first.
    public func lastDays(_ n: Int) -> [(label: String, count: Int)] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<n).reversed().compactMap { i -> (String, Int)? in
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { return nil }
            let key = dateKey(for: date)
            return (shortDayLabel(for: date), daily[key] ?? 0)
        }
    }

    public func incrementSent(count: Int = 1) {
        defaults.set(totalSent + count, forKey: Self.keyTotal)

        var d = daily
        let key = todayKey()
        d[key] = (d[key] ?? 0) + count

        // Keep only last 90 days.
        if let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) {
            let cutoffKey = dateKey(for: cutoff)
            d = d.filter { $0.key >= cutoffKey }
        }

        if let data = try? JSONEncoder().encode(d) {
            defaults.set(data, forKey: Self.keyDaily)
        }
    }

    private var daily: [String: Int] {
        guard let data = defaults.data(forKey: Self.keyDaily),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func sumDays(count: Int) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let d = daily
        return (0..<count).reduce(0) { sum, i in
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { return sum }
            return sum + (d[dateKey(for: date)] ?? 0)
        }
    }

    private func todayKey() -> String {
        return dateKey(for: Date())
    }

    private func dateKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func shortDayLabel(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        fmt.locale = Locale(identifier: "ru_RU")
        return fmt.string(from: date).capitalized
    }
}
