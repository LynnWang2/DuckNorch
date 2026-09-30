import AppKit
import UniformTypeIdentifiers

@main struct ModelTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let input = root.appendingPathComponent("screen-fixture.png")
        let model = WallpaperModel()
        model.folder = root.appendingPathComponent("drop-results", isDirectory: true)
        guard let item = NSItemProvider(contentsOf: input), model.receive([item]) else {
            throw DuckNorchError.message("TEST FAILED: file URL drop rejected")
        }
        for _ in 0..<1000 {
            if model.output != nil || model.error != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        guard model.input == input, let output = model.output, model.preview != nil,
              model.error == nil, !model.busy else {
            throw DuckNorchError.message("TEST FAILED: asynchronous drop and preview: \(model.error ?? "timeout")")
        }
        print("PASS: Finder-compatible file URL provider, asynchronous rendering, preview, saved output")
        if CommandLine.arguments.contains("--apply-and-restore") {
            let screen = NSScreen.screens.first!
            let workspace = NSWorkspace.shared
            guard let original = workspace.desktopImageURL(for: screen) else {
                throw DuckNorchError.message("Cannot safely test wallpaper without a restorable original URL")
            }
            let options = workspace.desktopImageOptions(for: screen) ?? [:]
            // Restore after success or failure. Keep the generated file in the test directory.
            var restored = false
            defer { if !restored { try? workspace.setDesktopImageURL(original, for: screen, options: options) } }
            model.applyWallpaper()
            for _ in 0..<250 {
                if workspace.desktopImageURL(for: screen)?.standardizedFileURL == output.standardizedFileURL { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            guard model.error == nil, workspace.desktopImageURL(for: screen)?.standardizedFileURL == output.standardizedFileURL else {
                throw DuckNorchError.message("TEST FAILED: apply wallpaper: \(model.error ?? "URL mismatch")")
            }
            try workspace.setDesktopImageURL(original, for: screen, options: options)
            for _ in 0..<250 {
                if workspace.desktopImageURL(for: screen)?.standardizedFileURL == original.standardizedFileURL { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            restored = true
            guard workspace.desktopImageURL(for: screen)?.standardizedFileURL == original.standardizedFileURL else {
                throw DuckNorchError.message("TEST FAILED: original wallpaper restoration")
            }
            print("PASS: one-click wallpaper method applied successfully; original wallpaper and options restored")
        }
    }
}
