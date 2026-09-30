#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p work
swiftc -O -parse-as-library -target arm64-apple-macosx27.0 \
    -framework AppKit -framework ImageIO -framework UniformTypeIdentifiers \
    Sources/WallpaperEngine.swift Tests/EngineTests.swift -o work/EngineTests
work/EngineTests "$PWD/work/fixtures"
