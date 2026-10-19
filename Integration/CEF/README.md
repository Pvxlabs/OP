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

Native icon-only query and refresh controls sit at top right. Header styling follows the owner-edited Figma “02 你的调整区” in file `xWHKogXYl3WijpAvXxn7MP`: bundled 13 pt Inter Bold and exact exported vector glyphs, 40 pt titlebar, night #1C1C1C / #A1A1AA, hover #2E2E2E with 4 pt corners and 32 x 30 pt bounds. Night inactive uses #6E6E6E title and hides both right icons as drawn. Light active remains #F9F9F9 / #313131 with the original tray glyph. Native traffic-light and title/button positions follow the exported coordinates; full-screen controls remain system-managed. See [the exact contract](../../docs/CEF-INTEGRATION-SPEC.md).

The query button sends a fixed execution-status message in the current ordinary ChatGPT conversation; ChatGPT looks up the task through CLINX using its existing context. OP has no task inbox, ID identification, pairing/binding, Observer configuration or background polling. Drafts, attachments, active generation and visible modals block sending with a native explanation; uncertain sends are never auto-retried. Startup is website-first and never automatically displays local copies. 页面 > 外观 selects 跟随系统 (default), 浅色 or 夜晚 and persists the choice for all native windows and recovery UI without reloading or restyling the official website. Commands remain in File/Page menus and the menu bar entry. macOS 27 visual appearance remains unverified.

## Installed application registration

After an installed bundle replacement, `./script/refresh-op-registration.py`
refreshes only OP registration metadata. It retains backup apps and data while
unregistering their known duplicate LaunchServices entries. It verifies signing
before refreshing the installed CEF identity and Spotlight. An automation
client that already cached a replaced bundle may still require its own restart;
this does not justify changing OP's bundle/data identity.

## Signing and upgrades

All framework Mach-O libraries, framework, Swift native library, helper bundles and main bundle are signed inside-out using one existing Apple Development/Developer ID identity. Set `OP_CEF_SIGN_IDENTITY` if selection must be explicit. Renderer/GPU helpers get allow-jit; sandbox remains enabled; no disable-library-validation entitlement. Strict verification must pass. Local Apple Development signing is not Developer ID distribution/notarization.

For an upgrade: retain the currently accepted artifact and lock, select an official ARM64 stable archive, verify archive digests, review CEF API/runtime/sandbox/security changes, update the lock and explicit CMake version guard together, rebuild all wrappers/helpers, repeat bridge/security/store/lifecycle tests, normal login and file UI acceptance, then compare matched real workloads. Do not update just the framework in an existing signed bundle. Distribution additionally needs Developer ID identity, entitlement review, nested signing, notarization/stapling and clean-host Gatekeeper validation.

Official references: [CEF usage and lifecycle](https://chromiumembedded.github.io/cef/general_usage.html), [macOS signing](https://chromiumembedded.github.io/cef/code_signing.html), [sandbox](https://chromiumembedded.github.io/cef/sandbox_setup.html), [CDP isolated-world scripts](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-addScriptToEvaluateOnNewDocument), [scoped bindings](https://chromedevtools.github.io/devtools-protocol/tot/Runtime/#method-addBinding).
