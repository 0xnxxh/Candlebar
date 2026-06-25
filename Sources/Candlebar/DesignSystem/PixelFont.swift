import SwiftUI

enum PixelFont {
    static let title = Font.system(.title3, design: .monospaced).weight(.black)
    static let section = Font.system(.caption, design: .monospaced).weight(.bold)
    static let body = Font.system(.body, design: .monospaced)
    static let number = Font.system(.body, design: .monospaced).weight(.semibold)
    static let tiny = Font.system(size: 10, weight: .bold, design: .monospaced)
}
