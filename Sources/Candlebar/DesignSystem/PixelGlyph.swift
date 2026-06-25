import SwiftUI

enum PixelGlyphKind {
    case priceUp
    case priceDown
    case live
    case stale
    case offline

    var cells: [Int] {
        switch self {
        case .priceUp:
            [2, 5, 6, 7, 10]
        case .priceDown:
            [2, 5, 6, 7, 10].map { 14 - $0 }
        case .live:
            [1, 2, 3, 5, 7, 9, 10, 11]
        case .stale:
            [0, 1, 2, 4, 6, 8, 9, 10]
        case .offline:
            [0, 4, 8, 6, 10, 2]
        }
    }

    var color: Color {
        switch self {
        case .priceUp, .live:
            PixelColors.up
        case .priceDown, .offline:
            PixelColors.down
        case .stale:
            PixelColors.warn
        }
    }
}

struct PixelGlyph: View {
    var kind: PixelGlyphKind
    var size: CGFloat = 3

    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { column in
                        Rectangle()
                            .fill(kind.cells.contains(row * 3 + column) ? kind.color : Color.clear)
                            .frame(width: size, height: size)
                    }
                }
            }
        }
        .frame(width: size * 3 + 2, height: size * 3 + 2)
    }
}

func glyphKind(for status: FeedStatus?) -> PixelGlyphKind {
    switch status {
    case .live:
        .live
    case .warning, .stale:
        .stale
    case .offline, .error:
        .offline
    case .idle, .loading, .none:
        .stale
    }
}

func glyphKind(for movement: PriceMovement, fallback status: FeedStatus?) -> PixelGlyphKind {
    switch movement {
    case .up:
        .priceUp
    case .down:
        .priceDown
    case .flat:
        glyphKind(for: status)
    }
}
