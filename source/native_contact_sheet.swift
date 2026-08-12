import AppKit
import Foundation

guard CommandLine.arguments.count > 2,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fputs("usage: native_contact_sheet.swift <atlas> <out.png>\n", stderr)
    exit(2)
}

let cellWidth = 192
let cellHeight = 208
let scale: CGFloat = 0.58
let outputWidth = Int(CGFloat(8 * cellWidth) * scale)
let outputHeight = Int(CGFloat(11 * cellHeight) * scale)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: outputWidth,
    pixelsHigh: outputHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: outputWidth, height: outputHeight).fill()
graphics.imageInterpolation = .none
source.draw(in: NSRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
NSGraphicsContext.restoreGraphicsState()

let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("wrote \(CommandLine.arguments[2])")
