#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CEF="${OP_CEF_ROOT:-$ROOT/../OP-CEF-Prototype/third_party/cef}"
BUILD="${OP_CEF_BUILD_DIR:-$ROOT/build/CEFIntegration}"
mkdir -p "$BUILD/evidence"
cmake -S "$ROOT/Integration/CEF" -B "$BUILD" -G Xcode -DCEF_ROOT="$CEF" -DPROJECT_ARCH=arm64 -DUSE_SANDBOX=ON -DCMAKE_OSX_ARCHITECTURES=arm64 -DOP_BUNDLE_ID="${OP_CEF_BUNDLE_ID:-local.personal.OP.CEFIntegration}" -DOP_PRODUCT_NAME="${OP_CEF_PRODUCT_NAME:-OP CEF Integration}"
cmake --build "$BUILD" --config Release --target OPCEFIntegration --parallel 4
python3 "$ROOT/Integration/CEF/sign.py" "$BUILD/Release/OPCEFIntegration.app"
# Build only: never stops, replaces or starts any currently running application.
