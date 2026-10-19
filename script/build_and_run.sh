#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
APP_NAME="OP"
APP_BUNDLE="$ROOT_DIR/build/Build/Products/Release/$APP_NAME.app"
case "$MODE" in run|--debug|--logs|--telemetry|--verify|--build) ;; *) echo 'usage: build_and_run.sh [--build|--debug|--logs|--telemetry|--verify]' >&2; exit 2;; esac
if [[ "$MODE" != --build ]]; then pkill -x "$APP_NAME" 2>/dev/null || true; fi
xcodebuild -project "$ROOT_DIR/ChatGPTNative.xcodeproj" -scheme ChatGPTNative -configuration Release -derivedDataPath "$ROOT_DIR/build" build
if [[ "$MODE" == --build ]]; then exit 0; fi
if [[ "$MODE" == --debug ]]; then exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"; fi
open -n "$APP_BUNDLE"
case "$MODE" in
--verify) sleep 2; pgrep -x "$APP_NAME" >/dev/null;;
--logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "OP"';;
--telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.personal.ChatGPTNative"';;
esac
