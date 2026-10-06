import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let number = Int(arguments[3]),
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
    fputs("Usage: make-version-icon.swift <logo.png> <output.png> <version-number>\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
base.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))

// A numbered corner badge distinguishes a versioned copy in the Dock.
let badge = NSRect(x: 12, y: 12, width: 400, height: 400)
NSColor(calibratedRed: 0.025, green: 0.04, blue: 0.07, alpha: 1).setFill()
NSBezierPath(ovalIn: badge.insetBy(dx: 9, dy: 9)).fill()
NSColor(calibratedRed: 1, green: 0.91, blue: 0.08, alpha: 1).setFill()
NSBezierPath(ovalIn: badge.insetBy(dx: 22, dy: 22)).fill()
let label = "\(number)" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: number >= 10 ? 185 : 245, weight: .heavy),
    .foregroundColor: NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.095, alpha: 1)
]
let labelSize = label.size(withAttributes: attributes)
label.draw(at: NSPoint(
    x: badge.midX - labelSize.width / 2,
    y: badge.midY - labelSize.height / 2 - 2
), withAttributes: attributes)

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode version icon PNG.\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: arguments[2]))
