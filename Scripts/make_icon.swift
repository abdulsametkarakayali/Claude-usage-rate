import AppKit
import Foundation

let sizes: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]

func render(size: Int, scale: Int) -> Data? {
    let px = size * scale
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: px, height: px)

    let radius = CGFloat(px) * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.88, green: 0.28, blue: 0.08, alpha: 1)
    ])!
    gradient.draw(in: rect, angle: 270)

    // Subtle inner highlight
    let highlight = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(px)*0.03, dy: CGFloat(px)*0.03),
                                 xRadius: radius*0.9, yRadius: radius*0.9)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    highlight.lineWidth = CGFloat(px) * 0.015
    highlight.stroke()

    // Draw SF Symbol in white, hierarchical palette
    let cfg = NSImage.SymbolConfiguration(pointSize: CGFloat(px) * 0.56, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
    if let sym = NSImage(systemSymbolName: "cpu.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let s = sym.size
        let imgRect = NSRect(x: (CGFloat(px) - s.width)/2,
                             y: (CGFloat(px) - s.height)/2,
                             width: s.width,
                             height: s.height)
        sym.draw(in: imgRect)
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return nil }
    return png
}

let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (size, scale) in sizes {
    let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
    guard let data = render(size: size, scale: scale) else { continue }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("done")
