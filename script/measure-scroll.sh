#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULT_DIR="${1:?absolute evidence directory}"
APP="$RESULT_DIR/OP Scroll Validation.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -swift-version 6 -parse-as-library -framework AppKit -framework SwiftUI -framework WebKit -lsqlite3 \
 "$ROOT_DIR"/ChatGPTNative/Services/*.swift "$ROOT_DIR"/ChatGPTNative/Views/*.swift "$ROOT_DIR/Tests/ScrollTests.swift" -o "$APP/Contents/MacOS/OP Scroll Validation"
python3 - "${3:-$ROOT_DIR/ChatGPTNative/Services/MessageObserver.js}" "$APP/Contents/Resources/MessageObserver.js" <<'PY'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
# Test-only isolated-world timing; no instrumentation is shipped in OP.
needle='  async function scan(interrupted = false) {'
instrument='''  const timedCollect = collect;
  collect = (...args) => {
    const began = performance.now();
    try { return timedCollect(...args); }
    finally { const m=globalThis.__scrollCollectMetrics; if(m){const ms=performance.now()-began;m.calls++;m.totalMs+=ms;m.maxMs=Math.max(m.maxMs,ms);} }
  };
'''
assert needle in source
Path(sys.argv[2]).write_text(source.replace(needle,instrument+needle).replace("  function consumeMutations(records) {", "  function consumeMutations(records) {\n    const t=performance.now();try { return timedMutations(records); } finally {const m=globalThis.__scrollMutationMetrics;if(m){const ms=performance.now()-t;m.calls++;m.totalMs+=ms;m.maxMs=Math.max(m.maxMs,ms);}}\n  }\n  function timedMutations(records) {"))
PY
cp "$ROOT_DIR/Tests/Resources/ReplyProtection.icns" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>OP Scroll Validation</string><key>CFBundleIdentifier</key><string>local.personal.ChatGPTNative.ScrollValidation</string><key>CFBundleName</key><string>OP Scroll Validation</string><key>CFBundleIconFile</key><string>ReplyProtection.icns</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSPrincipalClass</key><string>NSApplication</string></dict></plist>
PLIST
if [[ "${2:-}" == --website ]]; then
  # Reuse the user's already-authorized test profile through WebKit's normal
  # persistent store. Never read or copy its cookies or authentication files.
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.personal.ChatGPTNative.ProtectionTests' "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP"
open -n "$APP" --env "OP_TEST_CONVERSATION_ID=${OP_TEST_CONVERSATION_ID:-}" --args "$RESULT_DIR" "${2:-}"
