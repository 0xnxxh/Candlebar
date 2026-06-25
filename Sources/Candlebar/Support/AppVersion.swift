import Foundation

struct AppVersion: Comparable, CustomStringConvertible {
    let components: [Int]

    init(_ rawValue: String) {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        components = normalized
            .split(separator: ".")
            .map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }

    var description: String {
        components.map(String.init).joined(separator: ".")
    }

    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
