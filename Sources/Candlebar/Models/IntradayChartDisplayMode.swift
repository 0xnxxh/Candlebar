enum IntradayChartDisplayMode: String, Codable, CaseIterable, Identifiable {
    case fullDay
    case elapsedDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullDay: "FULL"
        case .elapsedDay: "AUTO"
        }
    }
}
