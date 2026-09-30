import AppKit
import ImageIO

guard CommandLine.arguments.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Usage: FlattenIcon.swift input.png output.png")
}
let width = image.width, height = image.height
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Could not create icon canvas")
}
// Blend the artwork's transparent corners into its charcoal tile so macOS
// applies its standard icon mask exactly once, with no second inset tile.
context.setFillColor(CGColor(srgbRed: 24.0 / 255, green: 25.0 / 255, blue: 30.0 / 255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))
context.setBlendMode(.normal)
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
guard let flattened = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Could not save flattened icon")
}
CGImageDestinationAddImage(destination, flattened, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not finish icon PNG") }
