<p align="center"><img src="Resources/AppIcon.png" width="128" alt="DuckNorth icon" /></p>
<h1 align="center">DuckNorth</h1>
<p align="center">轻量原生 macOS 壁纸工具，让刘海融入黑色菜单栏。</p>
<p align="center">Apple Silicon · macOS 27+ · MIT</p>

## 下载与使用

从 [Releases](https://github.com/LynnWang2/DuckNorth/releases/latest) 下载 `DuckNorth-1.0.1-macOS27-arm64.zip`，解压后打开 `DuckNorth.app`，也可以将它拖入“应用程序”文件夹。

1. 将图片拖入中央区域，或点击该区域选择壁纸。
2. 自动生成并预览 PNG；点击“设为桌面壁纸”应用。
3. 关闭窗口即可退出，壁纸效果继续保留。

生成文件默认保存到 `~/Pictures/DuckNorth`，支持选择其他保存文件夹。原图和已有结果均不会覆盖，每次生成独立 PNG。设置后请保留所使用的 PNG 文件。

安装包采用本地临时签名，没有 Developer ID 签名与 Apple 公证。首次下载打开若被系统阻止，先尝试打开一次，再到“系统设置 → 隐私与安全性”选择“仍要打开”。无需关闭 Gatekeeper。

## 功能与范围

- 按实际屏幕尺寸和缩放比例生成黑色菜单栏区域、系统窗口圆角和一像素黑边。
- 原生拖放、选图、预览、访达定位和一键设置壁纸。
- 图片居中填满，支持 EXIF 方向，大图在解码前缩小。
- 设置前检查屏幕变化；隐藏菜单栏时仍保留遮盖刘海的高度。
- 无网络访问、后台常驻、登录项或第三方运行依赖。

需要 Apple Silicon 和 macOS 27+，已在 macOS 27.0.1 验证。目前仅支持主菜单栏屏幕及其当前桌面空间，不管理其他显示器、Spaces 或动态壁纸。窗口圆角沿用上游的私有 `_cornerRadius` 读取方式，失效时回退到 16 pt。

## 构建

在 Apple Silicon + macOS 27 环境中安装 Xcode Command Line Tools，然后运行：

```sh
git clone https://github.com/LynnWang2/DuckNorth.git
cd DuckNorth
./build.sh
open dist/DuckNorth.app
```

默认输出 `dist/DuckNorth.app`，可通过 `./build.sh /absolute/output/path` 指定位置。图标转换、编译、打包及本地签名均由构建脚本完成，无需额外依赖。

## 测试

```sh
./test.sh
./test-model.sh
```

验证黑条、圆角、黑边、裁剪、照片方向、原图保持、结果唯一性、错误处理、屏幕测量、文件拖入、异步生成和预览。

可选壁纸集成测试：`./test-model.sh --apply-and-restore`。它会临时设置测试壁纸并恢复原桌面 URL 和选项，仅在能读取可恢复的原桌面图片时运行。

## 致谢与许可证

壁纸逻辑基于 [mezhevikin/norch](https://github.com/mezhevikin/norch)，参考提交 `400cb15769d33ddb7c97f661ff759684b35d16ec`。DuckNorth 是独立的图形界面封装，并非原项目的官方版本。

项目以 [MIT License](LICENSE) 开源，原项目许可证保留于 [Resources/Upstream-LICENSE](Resources/Upstream-LICENSE)，并随应用分发。图标为用户选定的 AI 辅助设计，包含于本项目的 MIT 分发范围。
