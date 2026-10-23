import SwiftUI

// macOS 经典以太网图标：< ●●● >
struct DuoEthernetGlyph: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        let w = size * 1.65
        let h = size * 1.4
        let cx = w / 2
        let cy = h / 2

        ZStack {
            // 左 <
            Path { p in
                p.move(to: CGPoint(x: cx - outerX, y: cy - halfH))
                p.addLine(to: CGPoint(x: cx - tipX, y: cy))
                p.addLine(to: CGPoint(x: cx - outerX, y: cy + halfH))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // 右 >
            Path { p in
                p.move(to: CGPoint(x: cx + outerX, y: cy - halfH))
                p.addLine(to: CGPoint(x: cx + tipX, y: cy))
                p.addLine(to: CGPoint(x: cx + outerX, y: cy + halfH))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            // 中间三点
            HStack(spacing: dotSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(color)
                        .frame(width: dotDiameter, height: dotDiameter)
                }
            }
        }
        .frame(width: w, height: h)
    }

    private var lineWidth: CGFloat { size * 0.148 }
    private var halfH: CGFloat { size * 0.483 }
    private var outerX: CGFloat { size * 0.248 }
    private var tipX: CGFloat { size * 0.578 }
    private var dotDiameter: CGFloat { size * 0.157 }
    private var dotSpacing: CGFloat { size * 0.107 }
}
