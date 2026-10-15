import SwiftUI

/// Classic wired-network symbol: one node on top, a bus below it, and two nodes underneath.
/// Everything is expressed as ratios of the glyph width so it scales with the menu bar icon size.
struct DuoEthernetShape: Shape {
    static let aspect: CGFloat = 0.92
    static let nodeSideRatio: CGFloat = 0.28
    static let nodeCornerRatio: CGFloat = 0.045

    func path(in rect: CGRect) -> Path {
        let side = rect.width * Self.nodeSideRatio
        let corner = CGSize(
            width: rect.width * Self.nodeCornerRatio,
            height: rect.width * Self.nodeCornerRatio
        )
        let top = CGRect(x: rect.midX - side / 2, y: rect.minY, width: side, height: side)
        let left = CGRect(x: rect.minX, y: rect.maxY - side, width: side, height: side)
        let right = CGRect(x: rect.maxX - side, y: rect.maxY - side, width: side, height: side)
        let busY = (top.maxY + left.minY) / 2

        var path = Path()
        for node in [top, left, right] {
            path.addRoundedRect(in: node, cornerSize: corner)
        }
        path.move(to: CGPoint(x: top.midX, y: top.maxY))
        path.addLine(to: CGPoint(x: top.midX, y: busY))
        path.move(to: CGPoint(x: left.midX, y: busY))
        path.addLine(to: CGPoint(x: right.midX, y: busY))
        path.move(to: CGPoint(x: left.midX, y: busY))
        path.addLine(to: CGPoint(x: left.midX, y: left.minY))
        path.move(to: CGPoint(x: right.midX, y: busY))
        path.addLine(to: CGPoint(x: right.midX, y: right.minY))
        return path
    }
}

struct DuoEthernetGlyph: View {
    let size: CGFloat
    let color: Color

    private var overallWidth: CGFloat { size * 0.92 }
    private var lineWidth: CGFloat { overallWidth * 0.09 }
    private var centerlineWidth: CGFloat { overallWidth - lineWidth }

    var body: some View {
        DuoEthernetShape()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: centerlineWidth, height: centerlineWidth * DuoEthernetShape.aspect)
    }
}
