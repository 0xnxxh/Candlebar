import SwiftUI

struct PixelFlash: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var movement: PriceMovement

    func body(content: Content) -> some View {
        content
            .background(flashColor)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: movement)
    }

    private var flashColor: Color {
        guard !reduceMotion else {
            return Color.clear
        }
        switch movement {
        case .up:
            return PixelColors.up.opacity(0.16)
        case .down:
            return PixelColors.down.opacity(0.16)
        case .flat:
            return Color.clear
        }
    }
}

extension View {
    func pixelFlash(_ movement: PriceMovement) -> some View {
        modifier(PixelFlash(movement: movement))
    }
}
