// Adapted from mezhevikin/norch (MIT). See Resources/Upstream-LICENSE.
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ScreenGeometry: Sendable, Equatable {
    let width: Int
    let height: Int
    let strip: CGFloat
    let radius: CGFloat

    @MainActor static func read(from screen: NSScreen) -> ScreenGeometry {
        let scale = screen.backingScaleFactor
        // maxY, rather than height, also works for displays with an offset origin.
        let topInset = max(screen.frame.maxY - screen.visibleFrame.maxY,
                           screen.safeAreaInsets.top)
        let probe = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
                             styleMask: [.titled], backing: .buffered, defer: false)
        var corner: CGFloat = 16
        if let frame = probe.contentView?.superview,
           frame.responds(to: NSSelectorFromString("_cornerRadius")),
           let value = frame.value(forKey: "_cornerRadius") as? CGFloat,
           value.isFinite, value > 0 {
            corner = value
        }
        return ScreenGeometry(width: Int((screen.frame.width * scale).rounded()),
                              height: Int((screen.frame.height * scale).rounded()),
                              strip: ((topInset + 1) * scale).rounded(), radius: corner * scale)
    }
}

enum DuckNorthError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum WallpaperEngine {
    static func render(input: URL, folder: URL, geometry: ScreenGeometry) throws -> URL {
        guard input.isFileURL,
              let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawWidth = props[kCGImagePropertyPixelWidth] as? Int,
              let rawHeight = props[kCGImagePropertyPixelHeight] as? Int,
              rawWidth > 0, rawHeight > 0 else {
            throw DuckNorthError.message("无法读取这张图片。请选择有效的 JPG、PNG、HEIC 或 TIFF 图片。")
        }
        let width = geometry.width, height = geometry.height
        guard width > 2, height > 2, width <= 16384, height <= 16384,
              geometry.strip.isFinite, geometry.strip >= 0, geometry.strip < CGFloat(height - 2),
              geometry.radius.isFinite, geometry.radius > 0 else {
            throw DuckNorthError.message("无法获取有效的屏幕尺寸，请重新打开 DuckNorth。")
        }
        // ImageIO applies camera orientation, and downsamples large photos before decoding.
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        let rotated = (5...8).contains(orientation)
        let iw = CGFloat(rotated ? rawHeight : rawWidth)
        let ih = CGFloat(rotated ? rawWidth : rawHeight)
        let ratio = max(CGFloat(width) / iw, CGFloat(height) / ih)
        let maxPixel = min(32768, max(1, Int(ceil(max(iw, ih) * min(1, ratio)))))
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceCreateThumbnailWithTransform: true,
                                      kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                                      kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw DuckNorthError.message("无法处理这张图片，可能是文件损坏或可用内存不足。")
        }
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(canvas)
        let picture = CGRect(x: 1, y: 1, width: canvas.width - 2,
                             height: canvas.height - geometry.strip - 1)
        context.addPath(CGPath(roundedRect: picture, cornerWidth: geometry.radius,
                               cornerHeight: geometry.radius, transform: nil))
        context.clip()
        let aspect = CGFloat(image.width) / CGFloat(image.height)
        var drawn = canvas
        if aspect > canvas.width / canvas.height { drawn.size.width = canvas.height * aspect }
        else { drawn.size.height = canvas.width / aspect }
        drawn.origin = CGPoint(x: canvas.midX - drawn.width / 2, y: canvas.midY - drawn.height / 2)
        context.interpolationQuality = .high
        context.draw(image, in: drawn)
        guard let rendered = context.makeImage() else {
            throw DuckNorthError.message("生成壁纸失败，请重试。")
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let base = String(input.deletingPathExtension().lastPathComponent.prefix(80))
        let suffix = UUID().uuidString
        let output = folder.appendingPathComponent("\(base)-ducknorth-\(formatter.string(from: Date()))-\(suffix.prefix(8)).png")
        let temporary = folder.appendingPathComponent(".ducknorth-\(suffix).png")
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL,
                                                                UTType.png.identifier as CFString, 1, nil) else {
            throw DuckNorthError.message("无法写入保存文件夹，请选择其他文件夹。")
        }
        CGImageDestinationAddImage(destination, rendered, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw DuckNorthError.message("保存 PNG 失败，请检查剩余空间及文件夹权限。")
        }
        // moveItem refuses to replace an existing file; the original is never opened for writing.
        try FileManager.default.moveItem(at: temporary, to: output)
        return output
    }
}
