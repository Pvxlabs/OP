# OP CEF isolated product candidate

This is a product integration target in the OP repository, not a replacement of the installed OP app. The existing WebKit Xcode target and all previously dirty sources remain intact.

## Build and verification

```sh
./script/build-cef.sh
./script/test-cef.py
open -n build/CEFIntegration/Release/OPCEFIntegration.app
```

Build entry point is build-only: it never kills or launches an existing app. Close this integration candidate normally before rebuilding it. Keep OPCEFPrototype and /Applications/OP.app untouched. Synthetic tests need exclusive use of the integration candidate's Chromium profile; they use separate SQLite files in the evidence directory. The normal integration profile is independent of OP and of the prototype.

CEF is reused from `../OP-CEF-Prototype/third_party/cef`, or an explicit `OP_CEF_ROOT`. Exact versions and original archive digests are in `version.lock.json`. The Xcode CMake project rejects another CEF version and requires arm64 and sandbox ON. No downloaded runtime belongs in Git. No global package installs are needed.

When the integration app is already used for work, build a separately identified candidate instead of changing its running bundle:

```sh
OP_CEF_BUILD_DIR="$PWD/build/CEFDelivery" \
OP_CEF_BUNDLE_ID=local.personal.OP.CEFValidation \
OP_CEF_PRODUCT_NAME='OP CEF Validation' ./script/build-cef.sh
OP_CEF_TEST_APP="$PWD/build/CEFDelivery/Release/OPCEFIntegration.app" ./script/test-cef.py
```

This variant has its own Chromium profile, SQLite directory and preferences under its bundle ID. Do not copy login data between variants. The latest 40 pt candidate uses this variant; the older running integration instance was preserved.

The build compiles a Swift 6 native library (SwiftUI, shared SQLite store/recovery) and Objective-C++ AppKit/CEF host. CEF owns its main message loop. AppKit owns NSApplication, NSWindow, standard window controls, menus and lifecycle. SwiftUI owns workspace selection, retained browser containers, local view and recovery sheets. A narrow C ABI connects these layers. There is no Electron, SwiftUI event-pump timer, offscreen frame-copy loop or website CSS change.

## State and privacy

- Bundle ID: `local.personal.OP.CEFIntegration`.
- Chromium: `~/Library/Application Support/local.personal.OP.CEFIntegration/Chromium`.
- Snapshots: same bundle root, `Snapshots/replies.sqlite`.
- Preferences: integration bundle's own UserDefaults.
- Optional manual diagnostics: same root, `Diagnostics/message-metadata.json`, overwritten, permission 0600. This contains bounded identity/length/state and native geometry metadata, not body text, cookies, headers or tokens.
- No automatic copying or opening of the installed OP SQLite database. Existing database schema and shared merge/protection code are compiled directly, unchanged. A later authorized cutover must make a consistent SQLite backup into the selected production data location and verify it; do not simply copy a live WAL database or point two apps at it.
- Normal website sign-in is independent. No browser Cookie or credential migration is implemented.

CEF's public in-process DevTools API installs a named isolated world and snapshot-only binding. No remote debugging server is configured. Browser-side gates require the expected world, current main frame, exact official origin, bounded payload, one outstanding batch, session/URL identity and validated message IDs. The shared store enforces sequence/deduplication/error rules. JS receives acknowledgement after SQLite ingestion. Native calls and arbitrary file/network APIs are not exposed to the remote main world. Native diagnostics never subscribes to Network or console domains.

Do not weaken the DOM conversation identity gate to compensate for empty identity attributes. Live first-turn identity gaps are explicitly a release blocker; see the acceptance report. `pageEnded` never means server-final/completely persisted.

## Bounded browser ownership

Each window retains at most three CEF BrowserSession/NSView pairs. Native hot selections reuse them. Cold selection loads matching native local text while the official page loads, then yields only after validated readable content. Memory-pressure callbacks discard inactive sessions. Renderer termination keeps the native window and local snapshots, marks interruption and offers manual retry through the protection menu. Shutdown attempts a bounded isolated flush, marks saved streams interrupted, closes all browsers, waits for OnBeforeClose and only then exits CEF's loop/CefShutdown. An unresponsive process or abrupt OS kill can still lose an unacknowledged increment.

File dialogs and clipboard use normal Chromium/AppKit handling; downloads explicitly request the native Save As dialog. User-initiated HTTPS popups get distinct native windows. OAuth provider edge cases, real website file operations and GPU crash recovery still require their own acceptance; implemented handlers alone are not proof.

## Native header

Only a native refresh icon at top right; no other custom titlebar buttons, glass title item, shadow or web restyling. Startup is website-first and never automatically displays local copies; SQLite/recent-list refresh runs after navigation is requested. Plain text, #F9F9F9 background and requested 40 pt measured windowed titlebar; AppKit still owns the red/yellow/green controls. Commands remain in File/Page menus and the menu bar entry. The current machine is macOS 26.6.2, built with Xcode 27 SDK. This does not verify macOS 27 visual appearance.

## Signing and upgrades

All framework Mach-O libraries, framework, Swift native library, helper bundles and main bundle are signed inside-out using one existing Apple Development/Developer ID identity. Set `OP_CEF_SIGN_IDENTITY` if selection must be explicit. Renderer/GPU helpers get allow-jit; sandbox remains enabled; no disable-library-validation entitlement. Strict verification must pass. Local Apple Development signing is not Developer ID distribution/notarization.

For an upgrade: retain the currently accepted artifact and lock, select an official ARM64 stable archive, verify archive digests, review CEF API/runtime/sandbox/security changes, update the lock and explicit CMake version guard together, rebuild all wrappers/helpers, repeat bridge/security/store/lifecycle tests, normal login and file UI acceptance, then compare matched real workloads. Do not update just the framework in an existing signed bundle. Distribution additionally needs Developer ID identity, entitlement review, nested signing, notarization/stapling and clean-host Gatekeeper validation.

Official references: [CEF usage and lifecycle](https://chromiumembedded.github.io/cef/general_usage.html), [macOS signing](https://chromiumembedded.github.io/cef/code_signing.html), [sandbox](https://chromiumembedded.github.io/cef/sandbox_setup.html), [CDP isolated-world scripts](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-addScriptToEvaluateOnNewDocument), [scoped bindings](https://chromedevtools.github.io/devtools-protocol/tot/Runtime/#method-addBinding).
