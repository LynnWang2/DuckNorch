import AppKit

guard CommandLine.arguments.count == 3,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: MakeIcon.swift source.png output.iconset")
}
let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

func render(_ size: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "DuckNorth.Icon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    source.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero,
                operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DuckNorth.Icon", code: 2)
    }
    return png
}

for logical in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(logical)x\(logical)\(scale == 2 ? "@2x" : "").png"
        try render(logical * scale).write(to: folder.appendingPathComponent(name))
    }
}
