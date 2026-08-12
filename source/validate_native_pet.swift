import AppKit
import Foundation

guard CommandLine.arguments.count > 1,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let tiff = source.tiffRepresentation,
      let image = NSBitmapImageRep(data: tiff) else {
    fputs("could not load image\n", stderr)
    exit(2)
}

let columns = 8
let rows = 11
let cellWidth = 192
let cellHeight = 208
let frameCounts = [6, 8, 8, 4, 5, 8, 6, 6, 6, 8, 8]
var errors: [String] = []

if image.pixelsWide != columns * cellWidth || image.pixelsHigh != rows * cellHeight {
    errors.append("expected 1536x2288, got \(image.pixelsWide)x\(image.pixelsHigh)")
}

func alphaAt(x: Int, y: Int) -> Int {
    guard let color = image.colorAt(x: x, y: y) else { return 0 }
    return Int((color.alphaComponent * 255).rounded())
}

for row in 0..<rows {
    for column in 0..<columns {
        var nontransparent = 0
        let originX = column * cellWidth
        let originY = row * cellHeight
        for y in originY..<(originY + cellHeight) {
            for x in originX..<(originX + cellWidth) where alphaAt(x: x, y: y) > 0 {
                nontransparent += 1
            }
        }
        let used = column < frameCounts[row]
        if used && nontransparent < 50 {
            errors.append("row \(row) col \(column) too sparse: \(nontransparent)")
        }
        if !used && nontransparent != 0 {
            errors.append("row \(row) col \(column) must be transparent: \(nontransparent)")
        }
    }
}

if errors.isEmpty {
    print("ok 1536x2288 RGBA, frame occupancy valid")
} else {
    for error in errors { print("error: \(error)") }
    exit(1)
}
