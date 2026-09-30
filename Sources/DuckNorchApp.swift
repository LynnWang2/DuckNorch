import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum ProjectInfo {
    static let name = "DuckNorch"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.1"
    static let projectURL = URL(string: "https://github.com/LynnWang2/DuckNorch")!
    static let upstreamURL = URL(string: "https://github.com/mezhevikin/norch")!
    static let licenseURL = URL(string: "https://github.com/LynnWang2/DuckNorch/blob/main/LICENSE")!
    @MainActor static var icon: NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return image }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }
}

@MainActor final class WallpaperModel: ObservableObject {
    @Published var input: URL?
    @Published var output: URL?
    @Published var preview: NSImage?
    @Published var busy = false
    @Published var targeted = false
    @Published var status = "选择一张喜欢的壁纸，剩下的交给 DuckNorch。"
    @Published var error: String?
    @Published var folder: URL
    @Published var details = ""
    private var renderedGeometry: ScreenGeometry?
    private var screenID: String?

    init() {
        if let stored = UserDefaults.standard.url(forKey: "outputFolder") { folder = stored }
        else {
            folder = (FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
                      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures"))
                .appendingPathComponent("DuckNorch", isDirectory: true)
        }
    }

    func chooseImage() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.title = "选择壁纸"
        panel.prompt = "生成壁纸"
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { select(url) }
    }

    func chooseFolder() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.title = "选择结果保存文件夹"
        panel.prompt = "保存到这里"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        if panel.runModal() == .OK, let url = panel.url {
            folder = url
            UserDefaults.standard.set(url, forKey: "outputFolder")
            if let input { select(input) }
        }
    }

    func select(_ url: URL) {
        guard !busy else { return }
        input = url
        output = nil
        preview = nil
        details = ""
        generate(applyAfter: false)
    }

    private func displayID(_ screen: NSScreen) -> String {
        String(describing: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "")
    }

    func generate(applyAfter: Bool) {
        guard !busy, let input else { return }
        // The first screen owns the primary menu bar. NSScreen.main may follow the active window.
        guard let screen = NSScreen.screens.first else {
            error = "未检测到可用屏幕。"; return
        }
        let geometry = ScreenGeometry.read(from: screen)
        let id = displayID(screen)
        let targetFolder = folder
        busy = true
        status = "正在生成壁纸…"
        error = nil
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try autoreleasepool { try WallpaperEngine.render(input: input, folder: targetFolder, geometry: geometry) }
                }.value
                output = result
                preview = NSImage(contentsOf: result)
                renderedGeometry = geometry
                screenID = id
                details = "\(screen.localizedName) · \(geometry.width) × \(geometry.height)"
                status = "PNG 已保存，原图保持不变。"
                busy = false
                if applyAfter { applyWallpaper() }
            } catch {
                busy = false
                self.error = error.localizedDescription
                status = "未能生成壁纸。可重新选图或更换保存文件夹。"
            }
        }
    }

    func applyWallpaper() {
        guard !busy, let output else { return }
        guard let screen = NSScreen.screens.first else { error = "未检测到可用屏幕。"; return }
        guard FileManager.default.fileExists(atPath: output.path) else {
            generate(applyAfter: true); return
        }
        let current = ScreenGeometry.read(from: screen)
        guard current == renderedGeometry, displayID(screen) == screenID else {
            generate(applyAfter: true); return
        }
        do {
            try NSWorkspace.shared.setDesktopImageURL(output, for: screen, options: [
                .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                .allowClipping: false
            ])
            status = "已设为桌面壁纸，现在可以关闭 DuckNorch。"
            error = nil
        } catch {
            self.error = "PNG 已保存，但设置桌面壁纸失败：\(error.localizedDescription)"
        }
    }

    func reveal() {
        if let output { NSWorkspace.shared.activateFileViewerSelecting([output]) }
    }

    func receive(_ providers: [NSItemProvider]) -> Bool {
        guard !busy, let item = providers.first(where: { $0.canLoadObject(ofClass: NSURL.self) }) else { return false }
        item.loadObject(ofClass: NSURL.self) { value, _ in
            let url = value as? URL
            Task { @MainActor in
                if let url, url.isFileURL { self.select(url) }
                else { self.error = "请从访达拖入一张图片文件。" }
            }
        }
        return true
    }
}

struct ContentView: View {
    @ObservedObject var model: WallpaperModel
    private let accent = Color(red: 0.27, green: 0.40, blue: 0.90)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: ProjectInfo.icon).resizable().scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("DuckNorch 图标")
                VStack(alignment: .leading, spacing: 5) {
                    Text("DuckNorch").font(.system(size: 29, weight: .semibold))
                    Text("让刘海融入壁纸").font(.system(size: 15)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color(nsColor: .controlBackgroundColor))
                if let preview = model.preview {
                    Image(nsImage: preview).resizable().aspectRatio(contentMode: .fit)
                        .padding(16).accessibilityLabel("处理后的壁纸预览")
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 36, weight: .light)).foregroundStyle(accent.opacity(0.8))
                        Text(model.busy ? "正在处理图片" : "拖入图片，或点击此处选择壁纸")
                            .font(.system(size: 17, weight: .medium))
                        Text("支持 JPG、PNG、HEIC、TIFF 等图片")
                            .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
                    }
                }
                if model.busy {
                    RoundedRectangle(cornerRadius: 18).fill(.regularMaterial)
                    ProgressView("正在生成…")
                }
                RoundedRectangle(cornerRadius: 18).strokeBorder(model.targeted ? accent : Color.primary.opacity(0.09),
                                                                style: StrokeStyle(lineWidth: model.targeted ? 2 : 1, dash: model.preview == nil ? [6, 4] : []))
            }
            .frame(height: 270)
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onDrop(of: [.fileURL], isTargeted: $model.targeted, perform: model.receive)
            .onTapGesture { if !model.busy { model.chooseImage() } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("拖入图片，或点击此处选择壁纸")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.chooseImage() }

            VStack(alignment: .center, spacing: 6) {
                Text(model.input?.lastPathComponent ?? "顶部纯黑 · 系统圆角 · 自动适配主屏幕")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                if !model.details.isEmpty {
                    Text(model.details).font(.system(size: 12)).foregroundStyle(.secondary)
                        .lineLimit(1).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
                Text(model.status).font(.system(size: 13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    .accessibilityLabel(model.status)
            }
            VStack(alignment: .center, spacing: 10) {
                Button(action: model.applyWallpaper) {
                    Label("设为桌面壁纸", systemImage: "desktopcomputer")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 230, height: 56)
                }.buttonStyle(.borderedProminent).tint(accent).controlSize(.large)
                    .disabled(model.output == nil || model.busy)
                    .keyboardShortcut(.return, modifiers: [])
                Button(action: model.reveal) {
                    Label("在访达中显示", systemImage: "folder")
                        .font(.system(size: 16, weight: .medium))
                        .frame(minHeight: 38)
                        .padding(.horizontal, 18)
                }.buttonStyle(.bordered).controlSize(.large)
                    .disabled(model.output == nil || model.busy)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Divider()
            HStack(spacing: 10) {
                Image(systemName: "folder").foregroundStyle(.secondary)
                Text("保存到：\(model.folder.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))")
                    .lineLimit(1).truncationMode(.middle).help(model.folder.path)
                Spacer(minLength: 8)
                Button("更改…", action: model.chooseFolder).controlSize(.large)
                    .disabled(model.busy)
            }
            .font(.system(size: 12)).foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
            Text("原图不覆盖，每次生成独立 PNG。关闭窗口即退出，无需后台运行。")
                .font(.system(size: 12)).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .padding(28).frame(width: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("DuckNorch", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("好", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(nsImage: ProjectInfo.icon).resizable().scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("DuckNorch 图标")
            VStack(spacing: 6) {
                Text(ProjectInfo.name).font(.system(size: 25, weight: .semibold))
                Text("版本 \(ProjectInfo.version)").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("项目链接").font(.system(size: 12)).foregroundStyle(.secondary)
                    Link("github.com/LynnWang2/DuckNorch", destination: ProjectInfo.projectURL)
                }
                VStack(spacing: 4) {
                    Text("原项目链接").font(.system(size: 12)).foregroundStyle(.secondary)
                    Link("github.com/mezhevikin/norch", destination: ProjectInfo.upstreamURL)
                }
                VStack(spacing: 4) {
                    Text("开源协议").font(.system(size: 12)).foregroundStyle(.secondary)
                    Link("MIT License", destination: ProjectInfo.licenseURL)
                }
            }.font(.system(size: 13))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28).padding(.vertical, 32)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = WallpaperModel()
    var window: NSWindow!
    var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let hosting = NSHostingView(rootView: ContentView(model: model))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 650, height: 620),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "DuckNorch"
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        makeMenus()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func windowWillClose(_ notification: Notification) {
        if let closed = notification.object as? NSWindow, closed === window {
            NSApp.terminate(nil)
        }
    }
    func application(_ sender: NSApplication, open urls: [URL]) {
        if let first = urls.first { model.select(first) }
    }
    @objc func choose() { model.chooseImage() }
    @objc func apply() { model.applyWallpaper() }
    @objc func help() {
        if let url = Bundle.main.url(forResource: "使用说明", withExtension: "txt") { NSWorkspace.shared.open(url) }
    }
    @objc func about() {
        if let aboutWindow { aboutWindow.makeKeyAndOrderFront(nil); return }
        let view = NSHostingView(rootView: AboutView())
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 430),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "关于 DuckNorch"
        panel.contentView = view
        panel.setContentSize(view.fittingSize)
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        aboutWindow = panel
    }
    private func makeMenus() {
        let bar = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "关于 DuckNorch", action: #selector(about), keyEquivalent: "").target = self
        app.addItem(.separator())
        app.addItem(withTitle: "隐藏 DuckNorch", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(.separator())
        app.addItem(withTitle: "退出 DuckNorch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem(); appItem.submenu = app; bar.addItem(appItem)
        let file = NSMenu(title: "文件")
        file.addItem(withTitle: "选择壁纸…", action: #selector(choose), keyEquivalent: "o").target = self
        file.addItem(withTitle: "设为桌面壁纸", action: #selector(apply), keyEquivalent: "") .target = self
        file.addItem(.separator())
        file.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileItem = NSMenuItem(title: "文件", action: nil, keyEquivalent: ""); fileItem.submenu = file; bar.addItem(fileItem)
        let help = NSMenu(title: "帮助")
        help.addItem(withTitle: "DuckNorch 使用说明", action: #selector(self.help), keyEquivalent: "").target = self
        let helpItem = NSMenuItem(title: "帮助", action: nil, keyEquivalent: ""); helpItem.submenu = help; bar.addItem(helpItem)
        NSApp.mainMenu = bar
    }
}

#if !DUCKNORTH_TESTING
@main struct DuckNorchMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
#endif
