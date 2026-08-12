import AppKit
import Foundation

let columns = 8
let rows = 11
let cellWidth = 192
let cellHeight = 208
let atlasWidth = columns * cellWidth
let atlasHeight = rows * cellHeight
let mascotScale: CGFloat = 0.5
let mascotBaseline: CGFloat = 192

struct Pose {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var headX: CGFloat = 0
    var headY: CGFloat = 0
    var blink = false
    var failed = false
    var typingPhase = 0
    var wavePhase: Int? = nil
    var sign: String? = nil
    var signColor = NSColor.systemGreen
    var lookX: CGFloat = 0
    var lookY: CGFloat = 0
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: atlasWidth,
    pixelsHigh: atlasHeight,
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
let context = graphics.cgContext
context.clear(CGRect(x: 0, y: 0, width: atlasWidth, height: atlasHeight))
context.translateBy(x: 0, y: CGFloat(atlasHeight))
context.scaleBy(x: 1, y: -1)
context.setShouldAntialias(false)
context.interpolationQuality = .none

let ink = NSColor(calibratedRed: 48 / 255, green: 45 / 255, blue: 49 / 255, alpha: 1)
let white = NSColor.white
let pink = NSColor(calibratedRed: 239 / 255, green: 66 / 255, blue: 104 / 255, alpha: 1)
let pinkLight = NSColor(calibratedRed: 1, green: 120 / 255, blue: 147 / 255, alpha: 1)
let blush = NSColor(calibratedRed: 1, green: 214 / 255, blue: 223 / 255, alpha: 1)
let yellow = NSColor(calibratedRed: 1, green: 200 / 255, blue: 61 / 255, alpha: 1)
let laptop = NSColor(calibratedRed: 185 / 255, green: 189 / 255, blue: 194 / 255, alpha: 1)
let laptopLight = NSColor(calibratedRed: 215 / 255, green: 218 / 255, blue: 221 / 255, alpha: 1)
let keys = NSColor(calibratedRed: 142 / 255, green: 148 / 255, blue: 155 / 255, alpha: 1)
let green = NSColor(calibratedRed: 105 / 255, green: 209 / 255, blue: 113 / 255, alpha: 1)
let helpYellow = NSColor(calibratedRed: 1, green: 211 / 255, blue: 78 / 255, alpha: 1)

func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: NSColor) {
    context.setFillColor(color.cgColor)
    context.fill(CGRect(x: x, y: y, width: width, height: height))
}

func polygon(_ points: [CGPoint], _ color: NSColor) {
    guard let first = points.first else { return }
    context.beginPath()
    context.move(to: first)
    for point in points.dropFirst() {
        context.addLine(to: point)
    }
    context.closePath()
    context.setFillColor(color.cgColor)
    context.fillPath()
}

let pixelLetters: [Character: [String]] = [
    "d": ["110", "101", "101", "101", "110"],
    "o": ["010", "101", "101", "101", "010"],
    "n": ["110", "101", "101", "101", "101"],
    "e": ["111", "100", "110", "100", "111"],
    "h": ["101", "101", "111", "101", "101"],
    "l": ["100", "100", "100", "100", "111"],
    "p": ["110", "101", "110", "100", "100"],
]

func pixelText(_ text: String, x: CGFloat, y: CGFloat, scale: CGFloat, color: NSColor) {
    var cursor = x
    for character in text {
        guard let rows = pixelLetters[character] else { continue }
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, value) in row.enumerated() where value == "1" {
                rect(
                    cursor + CGFloat(columnIndex) * scale,
                    y + CGFloat(rowIndex) * scale,
                    scale,
                    scale,
                    color
                )
            }
        }
        cursor += 4 * scale
    }
}

func drawPaw(centerX: CGFloat, centerY: CGFloat) {
    rect(centerX - 8, centerY - 8, 16, 16, ink)
    rect(centerX - 11, centerY - 5, 22, 10, ink)
    rect(centerX - 6, centerY - 6, 12, 12, white)
    rect(centerX - 8, centerY - 3, 16, 6, white)
}

func drawKitty(at origin: CGPoint, pose: Pose) {
    let ox = origin.x + pose.x
    let oy = origin.y + pose.y
    let hx = pose.headX
    let hy = pose.headY + (pose.failed ? 5 : 0)

    func px(_ value: CGFloat) -> CGFloat { ox + value }
    func py(_ value: CGFloat) -> CGFloat { oy + value }

    // Tiny body and collar.
    rect(px(65), py(104), 62, 68, ink)
    rect(px(71), py(108), 50, 64, white)
    rect(px(77), py(109), 13, 8, pink)
    rect(px(102), py(109), 13, 8, pink)
    rect(px(90), py(113), 12, 8, yellow)

    // Oversized stepped head and ears.
    polygon([
        CGPoint(x: px(25 + hx), y: py(50 + hy)),
        CGPoint(x: px(31 + hx), y: py(32 + hy)),
        CGPoint(x: px(40 + hx), y: py(18 + hy)),
        CGPoint(x: px(53 + hx), y: py(13 + hy)),
        CGPoint(x: px(67 + hx), y: py(33 + hy)),
        CGPoint(x: px(124 + hx), y: py(33 + hy)),
        CGPoint(x: px(138 + hx), y: py(13 + hy)),
        CGPoint(x: px(151 + hx), y: py(18 + hy)),
        CGPoint(x: px(160 + hx), y: py(32 + hy)),
        CGPoint(x: px(166 + hx), y: py(50 + hy)),
        CGPoint(x: px(166 + hx), y: py(93 + hy)),
        CGPoint(x: px(159 + hx), y: py(109 + hy)),
        CGPoint(x: px(146 + hx), y: py(120 + hy)),
        CGPoint(x: px(126 + hx), y: py(126 + hy)),
        CGPoint(x: px(66 + hx), y: py(126 + hy)),
        CGPoint(x: px(46 + hx), y: py(120 + hy)),
        CGPoint(x: px(33 + hx), y: py(109 + hy)),
        CGPoint(x: px(25 + hx), y: py(93 + hy)),
    ], ink)
    polygon([
        CGPoint(x: px(31 + hx), y: py(51 + hy)),
        CGPoint(x: px(37 + hx), y: py(35 + hy)),
        CGPoint(x: px(45 + hx), y: py(23 + hy)),
        CGPoint(x: px(51 + hx), y: py(20 + hy)),
        CGPoint(x: px(64 + hx), y: py(39 + hy)),
        CGPoint(x: px(127 + hx), y: py(39 + hy)),
        CGPoint(x: px(141 + hx), y: py(20 + hy)),
        CGPoint(x: px(147 + hx), y: py(23 + hy)),
        CGPoint(x: px(155 + hx), y: py(35 + hy)),
        CGPoint(x: px(160 + hx), y: py(51 + hy)),
        CGPoint(x: px(160 + hx), y: py(91 + hy)),
        CGPoint(x: px(153 + hx), y: py(104 + hy)),
        CGPoint(x: px(142 + hx), y: py(114 + hy)),
        CGPoint(x: px(123 + hx), y: py(120 + hy)),
        CGPoint(x: px(69 + hx), y: py(120 + hy)),
        CGPoint(x: px(50 + hx), y: py(114 + hy)),
        CGPoint(x: px(39 + hx), y: py(104 + hy)),
        CGPoint(x: px(31 + hx), y: py(91 + hy)),
    ], white)

    // Chunky whiskers.
    rect(px(8 + hx), py(67 + hy), 24, 4, ink)
    rect(px(5 + hx), py(80 + hy), 27, 4, ink)
    rect(px(8 + hx), py(94 + hy), 24, 4, ink)
    rect(px(159 + hx), py(67 + hy), 25, 4, ink)
    rect(px(160 + hx), py(80 + hy), 27, 4, ink)
    rect(px(159 + hx), py(94 + hy), 25, 4, ink)

    // Face.
    if pose.blink || pose.failed {
        rect(px(68 + hx + pose.lookX), py(80 + hy + pose.lookY), 10, 4, ink)
        rect(px(113 + hx + pose.lookX), py(80 + hy + pose.lookY), 10, 4, ink)
    } else {
        rect(px(69 + hx + pose.lookX), py(70 + hy + pose.lookY), 8, 19, ink)
        rect(px(114 + hx + pose.lookX), py(70 + hy + pose.lookY), 8, 19, ink)
    }
    rect(px(91 + hx + pose.lookX * 0.35), py(85 + hy + pose.lookY * 0.25), 10, 7, yellow)
    rect(px(48 + hx), py(99 + hy), 9, 4, blush)
    rect(px(135 + hx), py(99 + hy), 9, 4, blush)

    // Oversized bow.
    rect(px(132 + hx), py(15 + hy), 18, 35, ink)
    rect(px(145 + hx), py(20 + hy), 22, 30, ink)
    rect(px(161 + hx), py(25 + hy), 20, 35, ink)
    rect(px(136 + hx), py(20 + hy), 15, 25, pink)
    rect(px(150 + hx), py(24 + hy), 15, 22, pink)
    rect(px(166 + hx), py(30 + hy), 11, 24, pink)
    rect(px(139 + hx), py(20 + hy), 8, 5, pinkLight)
    rect(px(169 + hx), py(31 + hy), 7, 7, pinkLight)

    // Keyboard is on Kitty's side of the laptop.
    polygon([
        CGPoint(x: px(62), y: py(126)),
        CGPoint(x: px(130), y: py(126)),
        CGPoint(x: px(143), y: py(145)),
        CGPoint(x: px(49), y: py(145)),
    ], ink)
    polygon([
        CGPoint(x: px(67), y: py(131)),
        CGPoint(x: px(125), y: py(131)),
        CGPoint(x: px(134), y: py(140)),
        CGPoint(x: px(58), y: py(140)),
    ], laptopLight)
    for row in 0..<2 {
        for column in 0..<5 {
            let phaseOffset = (column + row) % 2
            let pressed = pose.typingPhase > 0 && phaseOffset == pose.typingPhase % 2
            rect(
                px(67 + CGFloat(column) * 12 + CGFloat(row) * 5),
                py(132 + CGFloat(row) * 5 + (pressed ? 2 : 0)),
                8,
                3,
                pressed ? (phaseOffset == 0 ? pink : yellow) : keys
            )
        }
    }

    // Short, round typing paws.
    let leftTap = pose.typingPhase == 1 ? 2 : 0
    let rightTap = pose.typingPhase == 2 ? 2 : 0
    if pose.sign == nil && pose.wavePhase == nil {
        drawPaw(centerX: px(65), centerY: py(131 + CGFloat(leftTap)))
    }
    if pose.wavePhase == nil {
        drawPaw(centerX: px(127), centerY: py(131 + CGFloat(rightTap)))
    } else {
        drawPaw(centerX: px(127), centerY: py(131))
        let waveOffsets: [(CGFloat, CGFloat)] = [(0, 0), (-7, -12), (4, -17), (-6, -10)]
        let offset = waveOffsets[pose.wavePhase! % waveOffsets.count]
        rect(px(55), py(116), 15, 20, ink)
        rect(px(59), py(119), 7, 14, white)
        rect(px(49 + offset.0 * 0.35), py(103 + offset.1 * 0.35), 16, 19, ink)
        rect(px(53 + offset.0 * 0.35), py(106 + offset.1 * 0.35), 7, 13, white)
        drawPaw(centerX: px(55 + offset.0), centerY: py(95 + offset.1))
    }

    // Viewer sees the back of the screen.
    rect(px(47), py(143), 98, 43, ink)
    rect(px(53), py(149), 86, 31, laptop)
    rect(px(58), py(153), 76, 4, laptopLight)
    rect(px(92), py(164), 8, 8, laptopLight)
    rect(px(41), py(184), 110, 8, ink)
    rect(px(48), py(185), 96, 3, keys)

    if let sign = pose.sign {
        let signX = px(15)
        let signY = py(2)
        let signWidth: CGFloat = 61
        rect(signX, signY, signWidth, 28, ink)
        rect(signX + 5, signY + 5, signWidth - 10, 18, pose.signColor)
        rect(px(39), py(29), 5, 77, ink)
        pixelText(sign, x: signX + 8, y: signY + 7, scale: 3, color: ink)
        rect(px(41), py(100), 12, 28, ink)
        rect(px(45), py(104), 5, 20, white)
        drawPaw(centerX: px(42), centerY: py(101))
    }
}

func poseFor(row: Int, column: Int) -> Pose? {
    switch row {
    case 0:
        guard column < 6 else { return nil }
        var pose = Pose()
        pose.y = [0, -1, -1, 0, -1, 0][column]
        pose.blink = column == 2 || column == 3
        return pose
    case 1:
        var pose = Pose()
        pose.x = [0, 2, 4, 6, 5, 3, 1, 0][column]
        pose.y = [0, -1, 0, 1, 0, -1, 0, 0][column]
        pose.headX = 2
        pose.typingPhase = column % 2 + 1
        return pose
    case 2:
        var pose = Pose()
        pose.x = [0, -2, -4, -6, -5, -3, -1, 0][column]
        pose.y = [0, -1, 0, 1, 0, -1, 0, 0][column]
        pose.headX = -2
        pose.typingPhase = column % 2 + 1
        return pose
    case 3:
        guard column < 4 else { return nil }
        var pose = Pose()
        pose.wavePhase = column
        pose.headX = column == 2 ? -1 : 0
        return pose
    case 4:
        guard column < 5 else { return nil }
        var pose = Pose()
        pose.wavePhase = [0, 1, 2, 3, 0][column]
        pose.headX = [0, -1, 0, -1, 0][column]
        pose.y = [0, -1, 0, -1, 0][column]
        return pose
    case 5:
        var pose = Pose()
        pose.failed = true
        pose.y = [0, 2, 4, 6, 7, 6, 4, 2][column]
        pose.headY = CGFloat([0, 1, 2, 3, 4, 3, 2, 1][column])
        return pose
    case 6:
        guard column < 6 else { return nil }
        var pose = Pose()
        pose.sign = "help"
        pose.signColor = helpYellow
        pose.y = [0, -1, 0, -1, 0, 0][column]
        pose.headX = column % 2 == 0 ? 0 : -1
        return pose
    case 7:
        guard column < 6 else { return nil }
        var pose = Pose()
        pose.typingPhase = column % 2 + 1
        pose.headY = CGFloat([0, 1, 0, 1, 0, 0][column])
        pose.blink = column == 4
        return pose
    case 8:
        guard column < 6 else { return nil }
        var pose = Pose()
        pose.sign = "done"
        pose.signColor = green
        pose.y = [0, -1, -2, -1, 0, 0][column]
        pose.blink = column == 2
        return pose
    case 9, 10:
        let index = (row - 9) * 8 + column
        let angle = Double(index) * 22.5 * .pi / 180
        var pose = Pose()
        pose.lookX = CGFloat(sin(angle) * 3.0).rounded()
        pose.lookY = CGFloat(-cos(angle) * 3.0).rounded()
        pose.headX = CGFloat(sin(angle) * 1.5).rounded()
        pose.headY = CGFloat(-cos(angle) * 1.0).rounded()
        return pose
    default:
        return nil
    }
}

for row in 0..<rows {
    for column in 0..<columns {
        guard let pose = poseFor(row: row, column: column) else { continue }
        let cellOrigin = CGPoint(
            x: CGFloat(column * cellWidth),
            y: CGFloat(row * cellHeight)
        )
        context.saveGState()
        context.translateBy(
            x: cellOrigin.x + CGFloat(cellWidth) * (1 - mascotScale) / 2,
            y: cellOrigin.y + mascotBaseline * (1 - mascotScale)
        )
        context.scaleBy(x: mascotScale, y: mascotScale)
        drawKitty(at: .zero, pose: pose)
        context.restoreGState()
    }
}

NSGraphicsContext.restoreGraphicsState()

guard CommandLine.arguments.count > 1 else {
    fputs("usage: make_native_pet.swift <output.png>\n", stderr)
    exit(2)
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fputs("could not encode png\n", stderr)
    exit(1)
}
try data.write(to: outputURL)
print("wrote \(outputURL.path) \(atlasWidth)x\(atlasHeight)")
