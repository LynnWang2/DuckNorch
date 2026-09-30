#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
destination="${1:-dist}"
mkdir -p "$destination/DuckNorth.app/Contents/MacOS" "$destination/DuckNorth.app/Contents/Resources" work
swiftc -O -whole-module-optimization -parse-as-library -target arm64-apple-macosx27.0 \
    -framework AppKit -framework SwiftUI -framework ImageIO -framework UniformTypeIdentifiers \
    Sources/WallpaperEngine.swift Sources/DuckNorthApp.swift \
    -o "$destination/DuckNorth.app/Contents/MacOS/DuckNorth"
cp Resources/Info.plist "$destination/DuckNorth.app/Contents/Info.plist"
cp Resources/Upstream-LICENSE Resources/使用说明.txt Resources/AppIcon.png \
    "$destination/DuckNorth.app/Contents/Resources/"
swift Tools/MakeIcon.swift Resources/AppIcon.png work/DuckNorth.iconset
iconutil -c icns work/DuckNorth.iconset -o "$destination/DuckNorth.app/Contents/Resources/DuckNorth.icns"
codesign --force --sign - "$destination/DuckNorth.app"
codesign --verify --deep --strict "$destination/DuckNorth.app"
echo "Built: $destination/DuckNorth.app"
