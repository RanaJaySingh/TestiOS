import Foundation

struct DateFormatters {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
    
    static let dayMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    static func formatMonthYear(_ date: Date) -> String {
        monthYear.string(from: date)
    }
    
    static func formatDayMonthYear(_ date: Date) -> String {
        dayMonthYear.string(from: date)
    }
    
    static func formatRelative(_ date: Date) -> String {
        relative.localizedString(for: date, relativeTo: Date())
    }
}

extension Date {
    var monthYearString: String {
        DateFormatters.formatMonthYear(self)
    }
    
    var dayMonthYearString: String {
        DateFormatters.formatDayMonthYear(self)
    }
}
