// Renders the workflow icons with AppKit shapes (no third-party or trademarked assets).
// Usage: swift tools/make_icons.swift [output-dir]   (default: workflow)
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "workflow"
try? FileManager.default.createDirectory(atPath: "\(outDir)/icons", withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func render(_ path: String, size: CGFloat = 256, draw: (CGRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true
    draw(CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

// Rounded-square background with a vertical gradient
func tile(_ r: CGRect, _ top: UInt32, _ bottom: UInt32) {
    let box = r.insetBy(dx: r.width * 0.06, dy: r.width * 0.06)
    let shape = NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225)
    NSGradient(starting: color(top), ending: color(bottom))!.draw(in: shape, angle: -90)
}

func stroke(_ p: NSBezierPath, _ r: CGRect, _ width: CGFloat = 0.06, _ c: NSColor = .white) {
    c.setStroke()
    p.lineWidth = r.width * width
    p.lineCapStyle = .round
    p.lineJoinStyle = .round
    p.stroke()
}

func pt(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y)
}

func rect(_ r: CGRect, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: r.minX + r.width * x, y: r.minY + r.height * y, width: r.width * w, height: r.height * h)
}

// Key lying diagonally: ring bow at top-left, shaft with two teeth towards bottom-right
func key(_ r: CGRect, _ c: NSColor = .white, width: CGFloat = 0.07) {
    let ring = NSBezierPath(ovalIn: rect(r, 0.2, 0.5, 0.3, 0.3))
    stroke(ring, r, width, c)
    let shaft = NSBezierPath()
    shaft.move(to: pt(r, 0.456, 0.544))
    shaft.line(to: pt(r, 0.78, 0.22))
    shaft.move(to: pt(r, 0.64, 0.34))
    shaft.line(to: pt(r, 0.72, 0.42))
    shaft.move(to: pt(r, 0.72, 0.26))
    shaft.line(to: pt(r, 0.8, 0.34))
    stroke(shaft, r, width, c)
}

func user(_ r: CGRect) {
    stroke(NSBezierPath(ovalIn: rect(r, 0.38, 0.52, 0.24, 0.24)), r)
    let body = NSBezierPath()
    body.move(to: pt(r, 0.26, 0.24))
    body.curve(to: pt(r, 0.74, 0.24), controlPoint1: pt(r, 0.28, 0.5), controlPoint2: pt(r, 0.72, 0.5))
    stroke(body, r)
}

func clock(_ r: CGRect) {
    stroke(NSBezierPath(ovalIn: rect(r, 0.22, 0.22, 0.56, 0.56)), r)
    let hands = NSBezierPath()
    hands.move(to: pt(r, 0.5, 0.64))
    hands.line(to: pt(r, 0.5, 0.5))
    hands.line(to: pt(r, 0.6, 0.42))
    stroke(hands, r)
}

func globe(_ r: CGRect) {
    let box = rect(r, 0.22, 0.22, 0.56, 0.56)
    stroke(NSBezierPath(ovalIn: box), r)
    stroke(NSBezierPath(ovalIn: rect(r, 0.38, 0.22, 0.24, 0.56)), r, 0.045)
    let lines = NSBezierPath()
    lines.move(to: pt(r, 0.23, 0.5)); lines.line(to: pt(r, 0.77, 0.5))
    stroke(lines, r, 0.045)
}

func list(_ r: CGRect) {
    let p = NSBezierPath()
    for y in [0.66, 0.5, 0.34] as [CGFloat] {
        p.move(to: pt(r, 0.4, y)); p.line(to: pt(r, 0.76, y))
    }
    stroke(p, r)
    for y in [0.66, 0.5, 0.34] as [CGFloat] {
        NSColor.white.setFill()
        NSBezierPath(ovalIn: rect(r, 0.22, y - 0.045, 0.09, 0.09)).fill()
    }
}

func padlock(_ r: CGRect, open: Bool = false) {
    let body = NSBezierPath(roundedRect: rect(r, 0.27, 0.2, 0.46, 0.34), xRadius: r.width * 0.05, yRadius: r.width * 0.05)
    NSColor.white.setFill(); body.fill()
    let shackle = NSBezierPath()
    shackle.move(to: pt(r, 0.36, 0.54))
    shackle.line(to: pt(r, 0.36, 0.64))
    shackle.appendArc(withCenter: pt(r, 0.5, 0.64), radius: r.width * 0.14, startAngle: 180, endAngle: 0, clockwise: true)
    shackle.line(to: pt(r, 0.64, open ? 0.66 : 0.54))
    stroke(shackle, r)
}

func card(_ r: CGRect) {
    let body = NSBezierPath(roundedRect: rect(r, 0.2, 0.3, 0.6, 0.4), xRadius: r.width * 0.05, yRadius: r.width * 0.05)
    stroke(body, r, 0.05)
    NSColor.white.setFill()
    NSBezierPath(rect: rect(r, 0.2, 0.54, 0.6, 0.07)).fill()
    let line = NSBezierPath(); line.move(to: pt(r, 0.28, 0.4)); line.line(to: pt(r, 0.46, 0.4))
    stroke(line, r, 0.045)
}

func note(_ r: CGRect) {
    let page = NSBezierPath(roundedRect: rect(r, 0.28, 0.2, 0.44, 0.6), xRadius: r.width * 0.05, yRadius: r.width * 0.05)
    stroke(page, r, 0.05)
    let lines = NSBezierPath()
    for y in [0.62, 0.5, 0.38] as [CGFloat] { lines.move(to: pt(r, 0.37, y)); lines.line(to: pt(r, 0.63, y)) }
    stroke(lines, r, 0.04)
}

func wifi(_ r: CGRect) {
    for (i, rad) in ([0.34, 0.22] as [CGFloat]).enumerated() {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: pt(r, 0.5, 0.3), radius: r.width * rad, startAngle: 45, endAngle: 135)
        stroke(arc, r, i == 0 ? 0.06 : 0.06)
    }
    NSColor.white.setFill()
    NSBezierPath(ovalIn: rect(r, 0.45, 0.28, 0.1, 0.1)).fill()
}

func person(_ r: CGRect) {
    let box = NSBezierPath(roundedRect: rect(r, 0.2, 0.28, 0.6, 0.44), xRadius: r.width * 0.05, yRadius: r.width * 0.05)
    stroke(box, r, 0.05)
    stroke(NSBezierPath(ovalIn: rect(r, 0.29, 0.46, 0.14, 0.14)), r, 0.04)
    let lines = NSBezierPath()
    lines.move(to: pt(r, 0.52, 0.56)); lines.line(to: pt(r, 0.7, 0.56))
    lines.move(to: pt(r, 0.52, 0.44)); lines.line(to: pt(r, 0.66, 0.44))
    lines.move(to: pt(r, 0.28, 0.37)); lines.line(to: pt(r, 0.44, 0.37))
    stroke(lines, r, 0.04)
}

func warning(_ r: CGRect) {
    let tri = NSBezierPath()
    tri.move(to: pt(r, 0.5, 0.76)); tri.line(to: pt(r, 0.8, 0.24)); tri.line(to: pt(r, 0.2, 0.24)); tri.close()
    stroke(tri, r)
    let bang = NSBezierPath(); bang.move(to: pt(r, 0.5, 0.58)); bang.line(to: pt(r, 0.5, 0.42))
    stroke(bang, r)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: rect(r, 0.465, 0.3, 0.07, 0.07)).fill()
}

func arrowBack(_ r: CGRect) {
    let p = NSBezierPath()
    p.move(to: pt(r, 0.72, 0.5)); p.line(to: pt(r, 0.3, 0.5))
    p.move(to: pt(r, 0.46, 0.66)); p.line(to: pt(r, 0.3, 0.5)); p.line(to: pt(r, 0.46, 0.34))
    stroke(p, r, 0.07)
}

func gear(_ r: CGRect) {
    stroke(NSBezierPath(ovalIn: rect(r, 0.36, 0.36, 0.28, 0.28)), r, 0.06)
    let teeth = NSBezierPath()
    for i in 0..<8 {
        let a = CGFloat(i) * .pi / 4
        teeth.move(to: CGPoint(x: r.midX + cos(a) * r.width * 0.2, y: r.midY + sin(a) * r.width * 0.2))
        teeth.line(to: CGPoint(x: r.midX + cos(a) * r.width * 0.29, y: r.midY + sin(a) * r.width * 0.29))
    }
    stroke(teeth, r, 0.08)
}

func text(_ r: CGRect) {
    let p = NSBezierPath()
    p.move(to: pt(r, 0.3, 0.7)); p.line(to: pt(r, 0.7, 0.7))
    p.move(to: pt(r, 0.5, 0.7)); p.line(to: pt(r, 0.5, 0.28))
    stroke(p, r, 0.08)
}

// Main icon: key over a deep-blue tile with a small shield-coloured highlight ring
render("\(outDir)/icon.png", size: 512) { r in
    tile(r, 0x2F7DF6, 0x1747A6)
    let glow = NSBezierPath(ovalIn: rect(r, 0.16, 0.46, 0.38, 0.38))
    color(0xFFFFFF, 0.16).setFill(); glow.fill()
    key(r, .white, width: 0.075)
}

let blue: (UInt32, UInt32) = (0x2F7DF6, 0x1747A6)
let icons: [(String, (UInt32, UInt32), (CGRect) -> Void)] = [
    ("login", blue, { r in key(r) }),
    ("password", (0x2F7DF6, 0x1747A6), { r in key(r) }),
    ("username", (0x22A06B, 0x13704A), { r in user(r) }),
    ("totp", (0x8B5CF6, 0x5B32C7), { r in clock(r) }),
    ("url", (0x0EA5E9, 0x0369A1), { r in globe(r) }),
    ("fields", (0x64748B, 0x3B4758), { r in list(r) }),
    ("text", (0x64748B, 0x3B4758), { r in text(r) }),
    ("secret", (0xF59E0B, 0xB45309), { r in key(r) }),
    ("creditcard", (0xF97316, 0xC2410C), { r in card(r) }),
    ("finance", (0x10B981, 0x047857), { r in card(r) }),
    ("note", (0xEAB308, 0xA16207), { r in note(r) }),
    ("wifi", (0x06B6D4, 0x0E7490), { r in wifi(r) }),
    ("identity", (0xEC4899, 0xBE185D), { r in person(r) }),
    ("trash", (0x9CA3AF, 0x6B7280), { r in key(r) }),
    ("lock", (0xEF4444, 0xB91C1C), { r in padlock(r) }),
    ("unlock", (0x22A06B, 0x13704A), { r in padlock(r, open: true) }),
    ("warning", (0xF59E0B, 0xB45309), { r in warning(r) }),
    ("back", (0x64748B, 0x3B4758), { r in arrowBack(r) }),
    ("settings", (0x64748B, 0x3B4758), { r in gear(r) }),
]

for (name, colors, draw) in icons {
    render("\(outDir)/icons/\(name).png") { r in
        tile(r, colors.0, colors.1)
        draw(r)
    }
}
print("Wrote \(icons.count + 1) icons to \(outDir)")
