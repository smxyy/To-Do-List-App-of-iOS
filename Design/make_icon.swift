// Draws the TaskBoard app icon (1024×1024) in light, dark and tinted variants.
// Usage: swift make_icon.swift <output-dir>
import AppKit
import CoreGraphics

let size: CGFloat = 1024

struct Palette {
    var bgTop: CGColor
    var bgBottom: CGColor
    var column: CGColor
    var card: CGColor
    var cardShadow: CGColor
    var line: CGColor
    var ring: CGColor
    var check: CGColor
    var checkMark: CGColor
    var draggedCard: CGColor
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let light = Palette(
    bgTop: rgb(0x4DA3FF), bgBottom: rgb(0x0058E0),
    column: rgb(0xFFFFFF, 0.20), card: rgb(0xFFFFFF), cardShadow: rgb(0x00205C, 0.28),
    line: rgb(0xC7D3E3), ring: rgb(0xB8C4D4),
    check: rgb(0x34C759), checkMark: rgb(0xFFFFFF), draggedCard: rgb(0xFFFFFF))

let dark = Palette(
    bgTop: rgb(0x23262D), bgBottom: rgb(0x0B0C0F),
    column: rgb(0xFFFFFF, 0.08), card: rgb(0x2E323A), cardShadow: rgb(0x000000, 0.5),
    line: rgb(0x555B66), ring: rgb(0x5F6672),
    check: rgb(0x30D158), checkMark: rgb(0x0B0C0F), draggedCard: rgb(0x0A84FF))

let tinted = Palette(
    bgTop: rgb(0x000000), bgBottom: rgb(0x000000),
    column: rgb(0xFFFFFF, 0.10), card: rgb(0xFFFFFF, 0.28), cardShadow: rgb(0x000000, 0),
    line: rgb(0xFFFFFF, 0.45), ring: rgb(0xFFFFFF, 0.5),
    check: rgb(0xFFFFFF), checkMark: rgb(0x000000), draggedCard: rgb(0xFFFFFF, 0.9))

func roundedRect(_ ctx: CGContext, _ r: CGRect, _ radius: CGFloat, _ color: CGColor) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(color)
    ctx.fillPath()
}

/// One task card: completion circle on the left, a title bar on the right.
func card(_ ctx: CGContext, _ r: CGRect, _ p: Palette, done: Bool, fill: CGColor? = nil, shadow: CGFloat = 10) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: shadow * 0.6), blur: shadow * 2, color: p.cardShadow)
    roundedRect(ctx, r, 30, fill ?? p.card)
    ctx.restoreGState()

    let d: CGFloat = 46
    let circle = CGRect(x: r.minX + 26, y: r.midY - d / 2, width: d, height: d)
    if done {
        ctx.setFillColor(p.check)
        ctx.fillEllipse(in: circle)
        ctx.setStrokeColor(p.checkMark)
        ctx.setLineWidth(8)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: circle.minX + 12, y: circle.midY + 1))
        ctx.addLine(to: CGPoint(x: circle.minX + 20, y: circle.midY + 10))
        ctx.addLine(to: CGPoint(x: circle.maxX - 11, y: circle.midY - 9))
        ctx.strokePath()
    } else {
        ctx.setStrokeColor(fill == nil ? p.ring : p.checkMark.copy(alpha: 0.8)!)
        ctx.setLineWidth(7)
        ctx.strokeEllipse(in: circle.insetBy(dx: 3.5, dy: 3.5))
    }
    let bar = CGRect(x: circle.maxX + 20, y: r.midY - 9, width: r.maxX - circle.maxX - 46, height: 18)
    roundedRect(ctx, bar, 9, fill == nil ? p.line : p.checkMark.copy(alpha: 0.75)!)
}

func render(_ p: Palette, to url: URL) {
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Work in top-left coordinates.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [p.bgTop, p.bgBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size), options: [])

    // Three columns: To do, Doing, Done.
    let colW: CGFloat = 236, gap: CGFloat = 30, top: CGFloat = 196, bottom: CGFloat = 828
    let left = (size - 3 * colW - 2 * gap) / 2
    let cardH: CGFloat = 104, inset: CGFloat = 18, spacing: CGFloat = 18
    func column(_ i: Int) -> CGRect {
        CGRect(x: left + CGFloat(i) * (colW + gap), y: top, width: colW, height: bottom - top)
    }
    func slot(_ i: Int, _ row: Int) -> CGRect {
        let c = column(i)
        return CGRect(x: c.minX + inset, y: c.minY + inset + CGFloat(row) * (cardH + spacing),
                      width: c.width - 2 * inset, height: cardH)
    }

    for i in 0..<3 { roundedRect(ctx, column(i), 48, p.column) }

    for row in 0..<4 { card(ctx, slot(0, row), p, done: false) }
    card(ctx, slot(1, 0), p, done: false)
    for row in 0..<2 { card(ctx, slot(2, row), p, done: true) }

    // A card mid-drag from Doing toward Done: lifted, tilted, accent colored.
    ctx.saveGState()
    let dragged = slot(1, 1).offsetBy(dx: 70, dy: 150)
    ctx.translateBy(x: dragged.midX, y: dragged.midY)
    ctx.rotate(by: -8 * .pi / 180)
    ctx.translateBy(x: -dragged.midX, y: -dragged.midY)
    card(ctx, dragged.insetBy(dx: -10, dy: -6), p, done: false, fill: p.draggedCard == p.card ? nil : p.draggedCard, shadow: 26)
    ctx.restoreGState()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
render(light, to: out.appendingPathComponent("AppIcon.png"))
render(dark, to: out.appendingPathComponent("AppIcon-Dark.png"))
render(tinted, to: out.appendingPathComponent("AppIcon-Tinted.png"))
print("done")
