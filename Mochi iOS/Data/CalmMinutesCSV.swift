import Foundation

/// Builds a "date,calmMinutes,overMinutes" CSV of daily calm/over minutes for
/// share-sheet export. Pure string assembly + a temp-file writer so it can be
/// fed straight into a SwiftUI `ShareLink`.
enum CalmMinutesCSV {
    static let header = "date,calmMinutes,overMinutes"

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Oldest → newest CSV rows, header first.
    static func make(from trend: [DayInsight]) -> String {
        var lines = [header]
        for day in trend {
            lines.append("\(dateFormatter.string(from: day.date)),\(day.calmMinutes),\(day.overMinutes)")
        }
        return lines.joined(separator: "\n")
    }

    /// Writes the CSV to a temporary file and returns its URL, or nil on failure.
    static func writeTempFile(from trend: [DayInsight]) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mochi-calm-minutes.csv")
        do {
            try make(from: trend).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
