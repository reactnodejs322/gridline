import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3,
      let base = NSImage(contentsOfFile: arguments[1]),
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1024,
        pixelsHigh: 1024,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
      ),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Usage: make-debug-icon.swift <logo.png> <output.png>\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
base.draw(in: canvas)

// A compact coral bug badge is rendered from vector shapes so both apps share one logo file.
let badge = NSRect(x: 684, y: 684, width: 340, height: 340)
NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.095, alpha: 1).setFill()
NSBezierPath(ovalIn: badge.insetBy(dx: 8, dy: 8)).fill()
NSColor(calibratedRed: 1, green: 0.91, blue: 0.08, alpha: 1).setStroke()
let rim = NSBezierPath(ovalIn: badge.insetBy(dx: 12, dy: 12))
rim.lineWidth = 18
rim.stroke()

let yellow = NSColor(calibratedRed: 1, green: 0.91, blue: 0.08, alpha: 1)
yellow.setFill()
yellow.setStroke()
context.cgContext.saveGState()
context.cgContext.translateBy(x: -219.6, y: -219.6)
context.cgContext.scaleBy(x: 1.214, y: 1.214)
let body = NSBezierPath(ovalIn: NSRect(x: 852, y: 800, width: 64, height: 132))
body.fill()
let head = NSBezierPath(ovalIn: NSRect(x: 860, y: 928, width: 48, height: 42))
head.fill()

func line(_ points: [(CGFloat, CGFloat)], width: CGFloat = 12) {
    let path = NSBezierPath()
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = width
    path.move(to: NSPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
    path.stroke()
}

// Antennae and three pairs of legs.
line([(866, 960), (843, 984), (822, 988)], width: 10)
line([(902, 960), (925, 984), (946, 988)], width: 10)
line([(852, 904), (826, 924), (808, 924)])
line([(916, 904), (942, 924), (960, 924)])
line([(852, 870), (824, 870), (806, 850)])
line([(916, 870), (944, 870), (964, 850)])
line([(856, 834), (830, 812), (812, 814)])
line([(912, 834), (938, 812), (956, 814)])

context.cgContext.restoreGState()
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode debug icon PNG.\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: arguments[2]))
