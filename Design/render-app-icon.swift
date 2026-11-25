import AppKit

// MacTweaks app icon: a Finder-style context menu with a highlighted "new" row and a pointer.
// Layout follows the macOS icon grid: 1024 canvas, 824 rounded square inset by 100.
//
// Regenerate the app icon (run from the repo root):
//   xcrun swiftc -o /tmp/render-app-icon Design/render-app-icon.swift
//   /tmp/render-app-icon /tmp/AppIcon-1024.png
//   for px in 16 32 64 128 256 512 1024; do
//     sips -z $px $px /tmp/AppIcon-1024.png --out MacTweaks/Assets.xcassets/AppIcon.appiconset/icon_$px.png
//   done

let canvas: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: canvas, height: canvas)
NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = context
let cg = context.cgContext
// Top-left origin, so the coordinates below read like a design spec.
cg.translateBy(x: 0, y: canvas)
cg.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}
func withShadow(offsetY: CGFloat, blur: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    // The context is flipped, so a positive height moves the shadow down on screen.
    cg.setShadow(offset: CGSize(width: 0, height: offsetY), blur: blur, color: NSColor.black.withAlphaComponent(alpha).cgColor)
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

// Background tile
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = rounded(tile, 185)
withShadow(offsetY: 12, blur: 28, alpha: 0.30) {
    color(0x2B3FD6).setFill()
    tilePath.fill()
}
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
NSGradient(starting: color(0x5FA0FF), ending: color(0x3A2FC9))!.draw(in: tile, angle: 90)
// Soft light at the top edge
NSGradient(starting: NSColor.white.withAlphaComponent(0.22), ending: NSColor.white.withAlphaComponent(0))!
    .draw(in: NSRect(x: tile.minX, y: tile.minY, width: tile.width, height: 360), angle: 90)
NSGraphicsContext.restoreGraphicsState()

// Context menu panel
let panel = NSRect(x: 240, y: 262, width: 460, height: 456)
withShadow(offsetY: 22, blur: 46, alpha: 0.35) {
    NSColor.white.setFill()
    rounded(panel, 58).fill()
}

let iconX: CGFloat = 300, barX: CGFloat = 345, rowHeight: CGFloat = 84
func row(y: CGFloat, barWidth: CGFloat) {
    color(0xC5CBD6).setFill()
    NSBezierPath(ovalIn: NSRect(x: iconX - 19, y: y + rowHeight / 2 - 19, width: 38, height: 38)).fill()
    color(0xDCE0E7).setFill()
    rounded(NSRect(x: barX, y: y + rowHeight / 2 - 12, width: barWidth, height: 24), 12).fill()
}
row(y: 296, barWidth: 230)
row(y: 380, barWidth: 280)

// Separator
color(0xE6E9EE).setFill()
NSRect(x: 280, y: 478, width: 380, height: 6).fill()

// Highlighted "New File" row
let highlightY: CGFloat = 500
let highlight = NSRect(x: 262, y: highlightY, width: 416, height: rowHeight)
NSGradient(starting: color(0x4C8DFF), ending: color(0x2F63F0))!.draw(in: rounded(highlight, 26), angle: 90)
NSColor.white.setFill()
let plusCenter = NSPoint(x: iconX, y: highlightY + rowHeight / 2)
rounded(NSRect(x: plusCenter.x - 21, y: plusCenter.y - 6, width: 42, height: 12), 6).fill()
rounded(NSRect(x: plusCenter.x - 6, y: plusCenter.y - 21, width: 12, height: 42), 6).fill()
rounded(NSRect(x: barX, y: highlightY + rowHeight / 2 - 12, width: 200, height: 24), 12).fill()

row(y: 600, barWidth: 250)

// Pointer, tip on the highlighted row
let arrow: [NSPoint] = [(0, 0), (0, 178), (44, 138), (74, 206), (106, 192), (77, 126), (134, 126)]
    .map { NSPoint(x: $0.0, y: $0.1) }
let tip = NSPoint(x: 590, y: highlightY + 38)
let scale: CGFloat = 1.2
let pointer = NSBezierPath()
pointer.move(to: NSPoint(x: tip.x + arrow[0].x * scale, y: tip.y + arrow[0].y * scale))
for point in arrow.dropFirst() {
    pointer.line(to: NSPoint(x: tip.x + point.x * scale, y: tip.y + point.y * scale))
}
pointer.close()
pointer.lineJoinStyle = .round
withShadow(offsetY: 10, blur: 22, alpha: 0.35) {
    NSColor.white.setFill()
    pointer.fill()
}
pointer.lineWidth = 16
NSColor.white.setStroke()
pointer.stroke()
color(0x111111).setFill()
pointer.fill()

NSGraphicsContext.restoreGraphicsState()
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try rep.representation(using: .png, properties: [:])!.write(to: out)
print(out.path)
