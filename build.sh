#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
destination="${1:-dist}"
mkdir -p "$destination/DuckNorch.app/Contents/MacOS" "$destination/DuckNorch.app/Contents/Resources" work
swiftc -O -whole-module-optimization -parse-as-library -target arm64-apple-macosx27.0 \
    -framework AppKit -framework SwiftUI -framework ImageIO -framework UniformTypeIdentifiers \
    Sources/WallpaperEngine.swift Sources/DuckNorchApp.swift \
    -o "$destination/DuckNorch.app/Contents/MacOS/DuckNorch"
cp Resources/Info.plist "$destination/DuckNorch.app/Contents/Info.plist"
cp LICENSE Resources/Upstream-LICENSE Resources/使用说明.txt \
    "$destination/DuckNorch.app/Contents/Resources/"
swift Tools/FlattenIcon.swift Resources/AppIcon-source.png work/AppIcon.png
cp work/AppIcon.png "$destination/DuckNorch.app/Contents/Resources/AppIcon.png"
swift Tools/MakeIcon.swift work/AppIcon.png work/DuckNorch.iconset
iconutil -c icns work/DuckNorch.iconset -o "$destination/DuckNorch.app/Contents/Resources/DuckNorch.icns"
codesign --force --sign - "$destination/DuckNorch.app"
codesign --verify --deep --strict "$destination/DuckNorch.app"
echo "Built: $destination/DuckNorch.app"
