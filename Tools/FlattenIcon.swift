import AppKit
import ImageIO

guard CommandLine.arguments.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Usage: FlattenIcon.swift input.png output.png")
}
let width = image.width, height = image.height
// The supplied artwork includes a dark canvas around its rounded tile. Crop
// that margin so the tile fills the macOS icon mask instead of appearing as a
// second, smaller app icon inside the system-rounded icon.
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Could not create icon canvas")
}
// Keep the artwork square and opaque. The system applies the only outer
// rounded-corner mask when displaying the icon.
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
