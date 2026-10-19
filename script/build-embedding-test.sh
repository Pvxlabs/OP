#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT_DIR="${1:?absolute output directory}"
DECK_SOURCE="${2:-$ROOT_DIR/ChatGPTNative/Views/BrowserDeck.swift}"
APP="$RESULT_DIR/OP Embedding Validation.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SOURCES=()
for SOURCE in "$ROOT_DIR"/ChatGPTNative/Views/*.swift; do
 [[ "$SOURCE" == */BrowserDeck.swift ]] || SOURCES+=("$SOURCE")
done
xcrun swiftc -O -swift-version 6 -parse-as-library -framework AppKit -framework SwiftUI -framework WebKit -lsqlite3 \
 "$ROOT_DIR"/ChatGPTNative/Services/*.swift "${SOURCES[@]}" "$DECK_SOURCE" "$ROOT_DIR/Tests/EmbeddingTests.swift" -o "$APP/Contents/MacOS/OP Embedding Validation"
cp "$ROOT_DIR/ChatGPTNative/Services/MessageObserver.js" "$ROOT_DIR/Tests/Resources/scroll-embedding.html" "$ROOT_DIR/Tests/Resources/ReplyProtection.icns" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>OP Embedding Validation</string><key>CFBundleIdentifier</key><string>local.personal.ChatGPTNative.ProtectionTests</string><key>CFBundleName</key><string>OP Embedding Validation</string><key>CFBundleIconFile</key><string>ReplyProtection.icns</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSPrincipalClass</key><string>NSApplication</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
