import Foundation

enum PriceMovement: String, Codable, Equatable {
    case up
    case down
    case flat

    init(previous: Decimal?, current: Decimal?) {
        guard let previous, let current else {
            self = .flat
            return
        }
        if current > previous {
            self = .up
        } else if current < previous {
            self = .down
        } else {
            self = .flat
        }
    }
}
