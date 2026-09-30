import AppKit
import ImageIO
import UniformTypeIdentifiers

func require(_ value: Bool, _ message: String) throws {
    if !value { throw DuckNorthError.message("TEST FAILED: " + message) }
}

func fixture(_ url: URL, width: Int, height: Int, orientation: Int = 1) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(red: 1, green: 0.2, blue: 0.1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    let image = context.makeImage()!
    let type = url.pathExtension == "tiff" ? UTType.tiff.identifier : UTType.png.identifier
    let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    try require(CGImageDestinationFinalize(destination), "write fixture")
}

struct Pixels {
    let width: Int, height: Int
    let bytes: [UInt8]
    init(_ url: URL) throws {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        width = image.width; height = image.height
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = Array(UnsafeBufferPointer(start: context.data!.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
    }
    func rgb(_ x: Int, _ y: Int) -> [UInt8] { Array(bytes[((y * width + x) * 4)..<((y * width + x) * 4 + 3)]) }
    func black(_ x: Int, _ y: Int) -> Bool { rgb(x, y) == [0, 0, 0] }
}

@main struct EngineTests {
    @MainActor static func main() throws {
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--compare" {
            let a = try Pixels(URL(fileURLWithPath: CommandLine.arguments[2]))
            let b = try Pixels(URL(fileURLWithPath: CommandLine.arguments[3]))
            try require(a.width == b.width && a.height == b.height && a.bytes == b.bytes,
                        "pixel match with upstream")
            print("PASS: rendered pixels exactly match upstream norch on the primary display")
            return
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("测试壁纸.png")
        try fixture(source, width: 320, height: 200)
        let original = try Data(contentsOf: source)
        let geometry = ScreenGeometry(width: 160, height: 100, strip: 10, radius: 12)
        let result = try WallpaperEngine.render(input: source, folder: root, geometry: geometry)
        let p = try Pixels(result)
        try require(p.width == 160 && p.height == 100, "output dimensions")
        // The decoder exposes the top row first.
        for y in 0..<10 { for x in 0..<160 { try require(p.black(x, y), "pure black menu strip") } }
        for y in 0..<100 {
            try require(p.black(0, y) && p.black(159, y), "one pixel side hairlines")
        }
        for x in 0..<160 { try require(p.black(x, 99), "one pixel bottom hairline") }
        try require(p.black(2, 11) && p.black(157, 11), "rounded top corners")
        try require(!p.black(80, 11) && !p.black(80, 50), "picture below strip")
        try require(p.rgb(40, 50)[0] > 200 && p.rgb(120, 50)[2] > 200, "center fill framing")
        let second = try WallpaperEngine.render(input: source, folder: root, geometry: geometry)
        try require(result != second && FileManager.default.fileExists(atPath: result.path), "unique outputs without overwrite")
        try require(try Data(contentsOf: source) == original, "original preserved")
        let oriented = root.appendingPathComponent("portrait.tiff")
        try fixture(oriented, width: 100, height: 160, orientation: 6)
        let rotated = try WallpaperEngine.render(input: oriented, folder: root, geometry: geometry)
        let rp = try Pixels(rotated)
        try require(rp.rgb(80, 30) != rp.rgb(80, 70), "EXIF orientation applied")
        let invalid = root.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: invalid)
        var rejected = false
        do { _ = try WallpaperEngine.render(input: invalid, folder: root, geometry: geometry) }
        catch { rejected = true }
        try require(rejected, "invalid file rejected")
        rejected = false
        do { _ = try WallpaperEngine.render(input: source, folder: source, geometry: geometry) }
        catch { rejected = true }
        try require(rejected, "non-directory output rejected")
        let screen = NSScreen.screens.first!
        let measured = ScreenGeometry.read(from: screen)
        try require(measured.width == Int((screen.frame.width * screen.backingScaleFactor).rounded()), "runtime screen scaling")
        let full = root.appendingPathComponent("screen-fixture.png")
        try fixture(full, width: measured.width, height: measured.height)
        let fullOutput = try WallpaperEngine.render(input: full, folder: root, geometry: measured)
        try fullOutput.path.write(to: root.appendingPathComponent("rendered-path.txt"), atomically: true, encoding: .utf8)
        print("PASS: dimensions, strip, corners, hairlines, crop, EXIF, unique files, original preservation, error paths, real screen geometry")
        print("SCREEN: \(measured.width)x\(measured.height), strip \(measured.strip)px, radius \(measured.radius)px")
    }
}
