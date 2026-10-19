#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$ROOT_DIR/build/ProtectionTests"
TEST_APP="$TEST_ROOT/Reply Protection Tests.app"
RESULT_DIR="$TEST_ROOT/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$TEST_APP/Contents/MacOS" "$TEST_APP/Contents/Resources" "$RESULT_DIR"
OPTIONS=(-Onone)
if [[ -n "${1:-}" ]]; then OPTIONS=(-O); fi
xcrun swiftc "${OPTIONS[@]}" -swift-version 6 -parse-as-library -framework AppKit -framework SwiftUI -framework WebKit -lsqlite3 \
  "$ROOT_DIR"/ChatGPTNative/Services/*.swift "$ROOT_DIR"/ChatGPTNative/Views/*.swift \
  "$ROOT_DIR/Tests/ProtectionTests.swift" -o "$TEST_APP/Contents/MacOS/Reply Protection Tests"
cp "$ROOT_DIR/ChatGPTNative/Services/MessageObserver.js" "$TEST_APP/Contents/Resources/"
cp "$ROOT_DIR/Tests/Resources/ReplyProtection.icns" "$TEST_APP/Contents/Resources/"

cat > "$TEST_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Reply Protection Tests</string>
<key>CFBundleIdentifier</key><string>local.personal.ChatGPTNative.ProtectionTests</string>
<key>CFBundleName</key><string>Reply Protection Tests</string>
<key>CFBundleIconFile</key><string>ReplyProtection.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$TEST_APP"
case "${1:-}" in
--preview|--stress|--notice|--notice-dark|--startup)
  open -n "$TEST_APP" --args "${1#--}" "$RESULT_DIR"
  echo "Evidence: $RESULT_DIR"
  exit 0;;
"") ;;
*) echo 'usage: test-protection.sh [--preview|--stress|--notice|--notice-dark|--startup]' >&2; exit 2;;
esac
python3 "$ROOT_DIR/Tests/http_fixture.py" "$RESULT_DIR/fixture-port" &
FIXTURE_PID=$!
trap 'kill "$FIXTURE_PID" 2>/dev/null || true' EXIT
for _ in {1..50}; do [[ -s "$RESULT_DIR/fixture-port" ]] && break; sleep 0.1; done
for PHASE in core restart; do
  open -n -W "$TEST_APP" --args "$PHASE" "$RESULT_DIR"
  python3 - "$RESULT_DIR/$PHASE-results.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    result = json.load(f)
print(json.dumps(result, ensure_ascii=False, indent=2))
if result['status'] != 'PASS':
    sys.exit(1)
PY
done
echo "Evidence: $RESULT_DIR"
