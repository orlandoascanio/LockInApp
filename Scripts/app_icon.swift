// Renders the LockIn app icon. Regenerate every size with:
//   swiftc -O Scripts/app_icon.swift -o /tmp/app_icon && /tmp/app_icon FocusLock/Resources/AppIcon.iconset iconset A
//   cp FocusLock/Resources/AppIcon.iconset/*.png FocusLock/Assets.xcassets/AppIcon.appiconset/
//   iconutil -c icns FocusLock/Resources/AppIcon.iconset -o FocusLock/Resources/AppIcon.icns
// Or pass just an output folder to get a comparison sheet of all variants.

import AppKit
import CoreGraphics

// LockIn app icon renderer. Draws on Apple's 1024 macOS grid: an 824pt
// continuous-corner tile centred with room for its shadow.

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let sand = rgb(0xF5F2E8), sandDeep = rgb(0xE6DFCB)
let moss = rgb(0x3B6148), mossLight = rgb(0x618C69), mossDark = rgb(0x24402F)
let clay = rgb(0xC07A58), ink = rgb(0x1F2A24)

/// Shadows are in device pixels, not user space, so they are scaled by hand.
var k: CGFloat = 1

/// Superellipse ("squircle") close to Apple's icon shape.
func squircle(in rect: CGRect, n: CGFloat = 5.2) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2, cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * copysign(pow(abs(c), 2 / n), c)
        let y = cy + b * copysign(pow(abs(s), 2 / n), s)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

func linear(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Tile with shadow, gradient fill, and a faint top highlight.
func tile(_ ctx: CGContext, top: CGColor, bottom: CGColor) -> CGPath {
    let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let path = squircle(in: rect)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * k), blur: 28 * k, color: rgb(0x000000, 0.28))
    ctx.addPath(path); ctx.setFillColor(bottom); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    linear(ctx, [top, bottom], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    // soft inner rim
    ctx.addPath(path); ctx.setStrokeColor(rgb(0xFFFFFF, 0.10)); ctx.setLineWidth(6); ctx.strokePath()
    ctx.restoreGState()
    return path
}

/// A padlock whose shackle is a countdown ring: the ring is the shackle's
/// arc continued all the way round, with the remaining time drawn bright.
struct Lock {
    var body: CGColor
    var ringTrack: CGColor
    var ringFill: CGColor
    var keyhole: CGColor
    var bodyShadow: Bool = true
}

func drawLock(_ ctx: CGContext, _ s: Lock, center: CGPoint = CGPoint(x: 512, y: 470), scale: CGFloat = 1) {
    let bodyW: CGFloat = 400 * scale, bodyH: CGFloat = 300 * scale
    let body = CGRect(x: center.x - bodyW / 2, y: center.y - bodyH / 2 - 40 * scale, width: bodyW, height: bodyH)
    let ringR: CGFloat = 132 * scale, ringW: CGFloat = 58 * scale
    let ringC = CGPoint(x: center.x, y: body.maxY + 20 * scale)

    // Shackle / ring track: full circle, mostly hidden behind the body.
    ctx.setLineCap(.butt)
    ctx.setLineWidth(ringW)
    ctx.setStrokeColor(s.ringTrack)
    ctx.addArc(center: ringC, radius: ringR, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
    ctx.strokePath()
    // Remaining time: from 12 o'clock clockwise about two thirds round.
    ctx.setLineCap(.round)
    ctx.setStrokeColor(s.ringFill)
    ctx.addArc(center: ringC, radius: ringR, startAngle: .pi / 2, endAngle: .pi / 2 - 1.28 * .pi, clockwise: true)
    ctx.strokePath()

    // Body
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 70 * scale, cornerHeight: 70 * scale, transform: nil)
    ctx.saveGState()
    if s.bodyShadow {
        ctx.setShadow(offset: CGSize(width: 0, height: -8 * scale * k), blur: 18 * scale * k, color: rgb(0x000000, 0.22))
    }
    ctx.addPath(bodyPath); ctx.setFillColor(s.body); ctx.fillPath()
    ctx.restoreGState()

    // Keyhole: circle + tapered stem
    let kc = CGPoint(x: center.x, y: body.midY + 28 * scale)
    ctx.setFillColor(s.keyhole)
    ctx.fillEllipse(in: CGRect(x: kc.x - 38 * scale, y: kc.y - 38 * scale, width: 76 * scale, height: 76 * scale))
    let stem = CGMutablePath()
    stem.move(to: CGPoint(x: kc.x - 20 * scale, y: kc.y - 10 * scale))
    stem.addLine(to: CGPoint(x: kc.x + 20 * scale, y: kc.y - 10 * scale))
    stem.addLine(to: CGPoint(x: kc.x + 28 * scale, y: kc.y - 112 * scale))
    stem.addQuadCurve(to: CGPoint(x: kc.x - 28 * scale, y: kc.y - 112 * scale), control: CGPoint(x: kc.x, y: kc.y - 124 * scale))
    stem.closeSubpath()
    ctx.addPath(stem); ctx.fillPath()
}

// Variant A — moss tile, sand lock, clay countdown.
func variantA(_ ctx: CGContext) {
    _ = tile(ctx, top: mossLight, bottom: mossDark)
    drawLock(ctx, Lock(body: sand, ringTrack: rgb(0xB9C9B4), ringFill: sand, keyhole: moss))
}

// Variant B — sand tile, moss lock, clay progress.
func variantB(_ ctx: CGContext) {
    _ = tile(ctx, top: rgb(0xFBF8EF), bottom: sandDeep)
    drawLock(ctx, Lock(body: moss, ringTrack: rgb(0x8FA892), ringFill: clay, keyhole: sand))
}

// Variant C — deep ink tile, moss lock body, sand ring: the night version.
func variantC(_ ctx: CGContext) {
    _ = tile(ctx, top: rgb(0x2C3A32), bottom: ink)
    drawLock(ctx, Lock(body: mossLight, ringTrack: rgb(0x55655B), ringFill: sand, keyhole: ink))
}

func render(size: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    k = CGFloat(size) / 1024
    ctx.scaleBy(x: k, y: k)
    draw(ctx)
    return ctx.makeImage()!
}

func write(_ image: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
let out = args[1]
let variants: [(String, (CGContext) -> Void)] = [("A", variantA), ("B", variantB), ("C", variantC)]

if args.count > 3, args[2] == "iconset" {
    // iconset <variant>: write every size macOS wants.
    let draw = variants.first { $0.0 == args[3] }!.1
    for base in [16, 32, 128, 256, 512] {
        write(render(size: base, draw), "\(out)/icon_\(base)x\(base).png")
        write(render(size: base * 2, draw), "\(out)/icon_\(base)x\(base)@2x.png")
    }
} else {
    // Comparison sheet: each variant large, then at 64 and 32 on light and dark strips.
    let W = 1500, H = 760
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(rgb(0xECECEC)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (i, (name, draw)) in variants.enumerated() {
        let x = 40 + i * 490
        ctx.draw(render(size: 440, draw), in: CGRect(x: x, y: 280, width: 440, height: 440))
        // light strip
        ctx.setFillColor(rgb(0xF6F6F6)); ctx.fill(CGRect(x: x, y: 140, width: 440, height: 110))
        ctx.draw(render(size: 128, draw), in: CGRect(x: x + 30, y: 155, width: 80, height: 80))
        ctx.draw(render(size: 64, draw), in: CGRect(x: x + 150, y: 179, width: 32, height: 32))
        ctx.draw(render(size: 32, draw), in: CGRect(x: x + 220, y: 187, width: 16, height: 16))
        // dark strip (Dock in dark mode)
        ctx.setFillColor(rgb(0x2A2A2C)); ctx.fill(CGRect(x: x, y: 20, width: 440, height: 110))
        ctx.draw(render(size: 128, draw), in: CGRect(x: x + 30, y: 35, width: 80, height: 80))
        ctx.draw(render(size: 64, draw), in: CGRect(x: x + 150, y: 59, width: 32, height: 32))
        ctx.draw(render(size: 32, draw), in: CGRect(x: x + 220, y: 67, width: 16, height: 16))
        let label = NSAttributedString(string: name, attributes: [.font: NSFont.boldSystemFont(ofSize: 34),
                                                                 .foregroundColor: NSColor.darkGray])
        let line = CTLineCreateWithAttributedString(label)
        ctx.textPosition = CGPoint(x: CGFloat(x + 300), y: 180)
        CTLineDraw(line, ctx)
        write(render(size: 1024, draw), "\(out)/variant-\(name).png")
    }
    write(ctx.makeImage()!, "\(out)/sheet.png")
}
