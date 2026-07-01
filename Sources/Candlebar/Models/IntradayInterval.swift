import Foundation

enum IntradayInterval: String, Codable, CaseIterable, Identifiable {
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"

    var id: String { rawValue }

    var title: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        }
    }

    var slotsPerDay: Int {
        Int((24 * 60 * 60) / seconds)
    }
}
