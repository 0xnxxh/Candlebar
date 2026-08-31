import AppKit
import Foundation

enum SidebarLayout {
    // A row is wide enough to carry a full price instead of an abbreviation:
    // reading the price is the whole point of the rail.
    static let itemWidth: CGFloat = 100
    static let sparklineSize = CGSize(width: 42, height: 13)
    static let rowLineSpacing: CGFloat = 1
    static let horizontalPadding: CGFloat = 8
    static let railVerticalPadding: CGFloat = 10
    static let itemSpacing: CGFloat = 6
    static var railWidth: CGFloat { itemWidth + horizontalPadding * 2 }
    static let itemHeight: CGFloat = 48

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

    /// Normalizes closes to 0...1 for the row sparkline. A flat series maps to
    /// the middle so the line stays visible instead of collapsing onto an edge.
    static func sparklineNormalized(values: [Decimal]) -> [Double] {
        let numbers = values
            .map { Double(truncating: $0 as NSDecimalNumber) }
            .filter(\.isFinite)
        guard let low = numbers.min(), let high = numbers.max() else { return [] }
        let span = high - low
        guard span > 0 else { return numbers.map { _ in 0.5 } }
        return numbers.map { ($0 - low) / span }
    }

    /// Picks the screen the rail belongs to. The remembered display wins; when
    /// it is unplugged the caller's fallback keeps the rail on screen instead of
    /// leaving it in the void.
    static func resolvedScreenIndex(preferredNumber: UInt32?, screenNumbers: [UInt32?]) -> Int? {
        guard let preferredNumber else { return nil }
        return screenNumbers.firstIndex(of: preferredNumber)
    }
}

extension NSScreen {
    /// `CGDirectDisplayID` for this screen, used to remember where the rail was
    /// docked across relaunches and display changes.
    var displayNumber: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
