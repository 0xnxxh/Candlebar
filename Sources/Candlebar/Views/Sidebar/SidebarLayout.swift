import AppKit
import Foundation

enum SidebarLayout {
    // Mirrors the relay-meter dock strip so both apps park identically.
    static let itemWidth: CGFloat = 52
    static let ringDiameter: CGFloat = 34
    static let labelHeight: CGFloat = 14
    static let labelSpacing: CGFloat = 4
    static let horizontalPadding: CGFloat = 8
    static let railVerticalPadding: CGFloat = 10
    static let itemSpacing: CGFloat = 12
    static var railWidth: CGFloat { itemWidth + horizontalPadding * 2 }
    static var itemHeight: CGFloat { ringDiameter + labelSpacing + labelHeight }

    /// The rail sits flush against the screen edge; only the bubble keeps a gap.
    static let bubbleGap: CGFloat = 8
    static let symbolContentWidth: CGFloat = 272

    static func railHeight(itemCount: Int) -> CGFloat {
        let count = max(itemCount, 0)
        let items = CGFloat(count) * itemHeight + CGFloat(max(count - 1, 0)) * itemSpacing
        return items + railVerticalPadding * 2
    }

    static func railFrame(
        visibleFrame: NSRect,
        itemCount: Int,
        edge: SidebarEdge,
        verticalPosition: Double,
    ) -> NSRect {
        let height = min(railHeight(itemCount: itemCount), visibleFrame.height)
        let x = switch edge {
        case .right: visibleFrame.maxX - railWidth
        case .left: visibleFrame.minX
        }
        return NSRect(
            x: x.rounded(),
            y: railOriginY(visibleFrame: visibleFrame, height: height, verticalPosition: verticalPosition).rounded(),
            width: railWidth,
            height: height,
        )
    }

    /// `verticalPosition` is the rail center measured from the top of the
    /// visible frame, so 0 pins it to the top and 1 to the bottom.
    static func railOriginY(visibleFrame: NSRect, height: CGFloat, verticalPosition: Double) -> CGFloat {
        let clampedPosition = min(max(verticalPosition, 0), 1)
        let travel = max(visibleFrame.height - height, 0)
        return visibleFrame.maxY - height - travel * clampedPosition
    }

    /// Inverse of `railOriginY`, used when a drag ends.
    static func verticalPosition(railFrame: NSRect, visibleFrame: NSRect) -> Double {
        let travel = max(visibleFrame.height - railFrame.height, 0)
        guard travel > 0 else { return 0.5 }
        let fromTop = visibleFrame.maxY - railFrame.maxY
        return min(max(fromTop / travel, 0), 1)
    }

    /// A rail dragged past the horizontal midpoint docks to the other edge.
    static func resolvedEdge(railCenterX: CGFloat, visibleFrame: NSRect) -> SidebarEdge {
        railCenterX < visibleFrame.midX ? .left : .right
    }

    /// Keeps a rail being dragged fully inside the visible frame.
    static func clampedDragFrame(_ frame: NSRect, visibleFrame: NSRect) -> NSRect {
        var clamped = frame
        clamped.origin.x = min(
            max(frame.origin.x, visibleFrame.minX),
            max(visibleFrame.maxX - frame.width, visibleFrame.minX),
        )
        clamped.origin.y = min(
            max(frame.origin.y, visibleFrame.minY),
            max(visibleFrame.maxY - frame.height, visibleFrame.minY),
        )
        return clamped
    }

    /// Center of the item at `itemIndex`, in screen coordinates. Items are laid
    /// out top-down inside the rail's vertical padding.
    static func itemCenterY(railFrame: NSRect, itemIndex: Int) -> CGFloat {
        let firstItemTop = railFrame.maxY - railVerticalPadding
        return firstItemTop - CGFloat(itemIndex) * (itemHeight + itemSpacing) - itemHeight / 2
    }

    /// Places a bubble of the given measured size beside its rail item, always
    /// opening away from the docked edge.
    static func bubbleFrame(
        railFrame: NSRect,
        itemIndex: Int,
        bubbleSize: CGSize,
        visibleFrame: NSRect,
        edge: SidebarEdge,
    ) -> NSRect {
        let height = min(bubbleSize.height, visibleFrame.height)
        let width = min(bubbleSize.width, visibleFrame.width)
        let centerY = itemCenterY(railFrame: railFrame, itemIndex: itemIndex)
        var y = centerY - height / 2
        y = min(max(y, visibleFrame.minY + bubbleGap), max(visibleFrame.maxY - height - bubbleGap, visibleFrame.minY + bubbleGap))

        let x = switch edge {
        case .right: railFrame.minX - width - bubbleGap
        case .left: railFrame.maxX + bubbleGap
        }
        let clampedX = min(
            max(x, visibleFrame.minX + bubbleGap),
            max(visibleFrame.maxX - width - bubbleGap, visibleFrame.minX + bubbleGap),
        )

        return NSRect(x: clampedX.rounded(), y: y.rounded(), width: width, height: height)
    }

    /// Maps an intraday percent change onto a 0...1 ring fill. ±10% or more
    /// fills the ring completely.
    static func ringFraction(percent: Decimal?) -> Double {
        guard let percent else { return 0 }
        let magnitude = Double(truncating: percent.magnitude as NSDecimalNumber)
        guard magnitude.isFinite else { return 0 }
        return min(magnitude / 10, 1)
    }
}
