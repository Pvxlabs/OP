#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE="${1:?prepare or measure}"
RESULT_DIR="${2:?absolute evidence directory}"
# This script builds current sources only. Never overwrite the frozen pre-change host.
VARIANT="${3:-optimized}"
if [[ "$VARIANT" == baseline ]]; then
  echo 'baseline is reserved for the frozen pre-change binary; use a new current-source label' >&2
  exit 2
fi
APP="$ROOT_DIR/build/CachePerformance/$VARIANT/OP Performance Tests.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$RESULT_DIR"
FLAGS=(-D CACHE_OPTIMIZED)
xcrun swiftc -O -swift-version 6 -parse-as-library -framework AppKit -framework SwiftUI -framework WebKit -lsqlite3 "${FLAGS[@]}" \
 "$ROOT_DIR"/ChatGPTNative/Services/*.swift "$ROOT_DIR"/ChatGPTNative/Views/*.swift "$ROOT_DIR/Tests/PerformanceTests.swift" -o "$APP/Contents/MacOS/OP Performance Tests"
cp "$ROOT_DIR/ChatGPTNative/Services/MessageObserver.js" "$APP/Contents/Resources/"
cp "$ROOT_DIR/Tests/Resources/ReplyProtection.icns" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>OP Performance Tests</string><key>CFBundleIdentifier</key><string>local.personal.ChatGPTNative.ProtectionTests</string><key>CFBundleName</key><string>OP Performance Tests</string><key>CFBundleIconFile</key><string>ReplyProtection.icns</string>
<key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSPrincipalClass</key><string>NSApplication</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
open -n "$APP" --env "OP_TEST_CONVERSATION_ID=${OP_TEST_CONVERSATION_ID:-}" --args "$PHASE" "$RESULT_DIR"
echo "$APP"
