#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p work
swiftc -O -parse-as-library -D DUCKNORTH_TESTING -target arm64-apple-macosx27.0 \
    -framework AppKit -framework SwiftUI -framework ImageIO -framework UniformTypeIdentifiers \
    Sources/WallpaperEngine.swift Sources/DuckNorthApp.swift Tests/ModelTests.swift -o work/ModelTests
work/ModelTests "$PWD/work/fixtures" "$@"
