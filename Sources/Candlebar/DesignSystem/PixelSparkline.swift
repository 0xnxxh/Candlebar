import SwiftUI

/// Tiny trend line for a rail row: enough shape to read direction at a glance,
/// no axes or labels. Falls back to a flat track when there is nothing to plot.
struct PixelSparkline: View {
    var values: [Decimal]
    var tint: Color
    var size: CGSize = SidebarLayout.sparklineSize

    var body: some View {
        let points = SidebarLayout.sparklineNormalized(values: values)
        return Canvas { context, canvasSize in
            guard points.count > 1 else {
                drawFlatTrack(context: context, size: canvasSize)
                return
            }
            let step = canvasSize.width / CGFloat(points.count - 1)
            var path = Path()
            for (index, point) in points.enumerated() {
                let position = CGPoint(
                    x: step * CGFloat(index),
                    y: canvasSize.height - CGFloat(point) * canvasSize.height,
                )
                if index == 0 {
                    path.move(to: position)
                } else {
                    path.addLine(to: position)
                }
            }
            context.stroke(path, with: .color(tint), lineWidth: 1.5)
        }
        .frame(width: size.width, height: size.height)
    }

    private func drawFlatTrack(context: GraphicsContext, size: CGSize) {
        var line = Path()
        line.move(to: CGPoint(x: 0, y: size.height / 2))
        line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(line, with: .color(PixelColors.line.opacity(0.55)), lineWidth: 1)
    }
}
