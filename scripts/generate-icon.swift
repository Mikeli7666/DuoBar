// Rebuild with: swift scripts/generate-icon.swift
import AppKit
import Foundation

let output = URL(fileURLWithPath: "DuoBar/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var entries: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let tile = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 208, yRadius: 208)
        NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.29, alpha: 1), ending: NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.10, alpha: 1))!.draw(in: tile, angle: -90)
        func arc(radius: CGFloat, start: CGFloat, end: CGFloat, width: CGFloat, color: NSColor) {
            let path = NSBezierPath()
            path.appendArc(withCenter: NSPoint(x: 512, y: 510), radius: radius, startAngle: start, endAngle: end)
            path.lineWidth = width
            path.lineCapStyle = .round
            color.setStroke()
            path.stroke()
        }
        arc(radius: 310, start: -38, end: 218, width: 56, color: NSColor(calibratedRed: 0.28, green: 0.91, blue: 0.64, alpha: 1))
        // Wi-Fi bands share the menu-bar glyph's simple rounded geometry.
        for radius: CGFloat in [178, 105] {
            let path = NSBezierPath()
            path.appendArc(withCenter: NSPoint(x: 512, y: 416), radius: radius, startAngle: 42, endAngle: 138)
            path.lineWidth = 43
            path.lineCapStyle = .round
            NSColor.white.setStroke()
            path.stroke()
        }
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 488, y: 392, width: 48, height: 48)).fill()
        for (x, y) in [(377.0, 270.0), (467.0, 244.0), (557.0, 244.0), (647.0, 270.0)] {
            NSColor(calibratedRed: 0.36, green: 0.73, blue: 1, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - 23, y: y - 23, width: 46, height: 46)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)@\(scale)x.png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let manifest: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
