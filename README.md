# OP

Personal macOS ChatGPT client with a **Swift 6 / SwiftUI / AppKit native shell
and CEF (Chromium) rendering backend**. It loads https://chatgpt.com/ directly,
uses normal website sign-in, and does not use the OpenAI API or Electron.

The current local Air delivery is **0.3.3**, installed as `/Applications/OP.app`.
The owner accepted the current Figma-matched header and everyday experience on Air on 2026-10-20.
WebKit remains available as the 0.2.0 fallback; its source and historical tags are
retained. This repository publishes source, tests and reviewed acceptance notes,
not Chromium binaries, app bundles, login profiles or chat snapshots.

## Primary CEF build

Requires an Apple Silicon Mac, macOS 14+, Xcode, CMake, Python 3 and an existing
local signing identity. Obtain the official ARM64 CEF distribution pinned in
[`version.lock.json`](Integration/CEF/version.lock.json), verify its digests,
extract it locally and set `OP_CEF_ROOT` to the extracted directory. The CEF SDK
and runtime are separate dependencies and are not vendored in Git.

Build a separately identified instance so testing does not share the installed
OP's Chromium profile or SQLite database:

```sh
export OP_CEF_ROOT=/absolute/path/to/extracted/cef
OP_CEF_BUILD_DIR="$PWD/build/CEFReview" \
OP_CEF_BUNDLE_ID=local.personal.OP.CEFReview \
OP_CEF_PRODUCT_NAME='OP CEF Review' ./script/build-cef.sh
OP_CEF_TEST_APP="$PWD/build/CEFReview/Release/OPCEFIntegration.app" ./script/test-cef.py
open -n build/CEFReview/Release/OPCEFIntegration.app
```

Close that review instance before rebuilding or running its synthetic tests.
The build script never replaces or restarts `/Applications/OP.app`. Sign in
normally within each separately identified instance; no Cookie migration is used.

Normal navigation always shows the official webpage. Local replies appear only
when you choose File > 本地回复副本…; they never automatically cover loading or
error pages.

The CEF target shares the SQLite model/store and local recovery code with the
WebKit baseline. It provides a restricted isolated-world reply observer, a
three-session LRU per window, native menus and shortcuts, and explicit local
recovery. Startup shows the website without automatically opening local-copy UI.
The native header is 40 pt with a bold refresh symbol, an inactive title treatment
and native window controls. **页面 > 外观** offers 跟随系统 (default), 浅色 and 夜晚;
the selection is remembered across launches and applies to all native windows and
recovery panels. Light chrome uses #F9F9F9 with #313131 controls; night chrome uses
#1C1C1C with #A1A1AA active title/icons and a #6E6E6E inactive title.
Night inactive hides the right icons as drawn in the owner-edited Figma design.
Hover backgrounds are #2E2E2E with 4 pt corners. The website keeps its own appearance setting.

“页面 > 后台回复完成提醒” enables local macOS notifications when an observed
ChatGPT reply finishes while OP is in the background. Foreground replies, history,
manual stops and detected errors stay silent. Notification delivery remains subject
to macOS permission, Focus and screen-sharing settings.

See the [CEF build/runtime guide](Integration/CEF/README.md),
[integration contract](docs/CEF-INTEGRATION-SPEC.md) and
[acceptance record](docs/CEF-INTEGRATION-ACCEPTANCE.md).
Synthetic acceptance for the simplified query action is recorded in
[the acceptance notes](docs/CEF-INTEGRATION-ACCEPTANCE.md). A fresh first-turn DOM identity gap remains
unresolved, and matched real display-frame/CPU/memory comparisons, some file/OAuth
flows and distribution notarization are not fully accepted. Local capture cannot
protect text that never reached the client or cannot be reliably attributed.

CEF uses `~/Library/Application Support/local.personal.OP.CEFIntegration/` for
its own Chromium profile, preferences and SQLite snapshots. The WebKit data path
below remains separate. Snapshots are local plaintext; the app does not upload
them to an additional service. Local signing is not notarized distribution.

Project-authored code is available under the [MIT license](LICENSE). CEF and its
sample-derived code retain their [upstream license](Integration/CEF/Resources/LICENSE-CEF.txt);
Chromium runtime dependencies retain their own notices. OP is an independent
personal client and is not affiliated with OpenAI.

Manual official-site WebKit tests require your own independent synthetic
conversations. Set `OP_TEST_CONVERSATION_ID` for protection/scroll/cache preparation,
or `OP_TEST_CONVERSATION_IDS` to three distinct comma-separated UUIDs for embedding
comparisons. The launch scripts forward these with `open --env`; a manually
launched protection host also needs `open --env OP_TEST_CONVERSATION_ID=...`.
Missing/invalid configuration is rejected rather than opening an account-specific
example. Keep these values and raw results local. Synthetic offline/loopback
fixtures need no account-linked IDs.

## Query CLINX execution in the current conversation

Click the **query icon** (square checkmark at night, tray in light mode) beside refresh to send this ordinary message in the current
ChatGPT conversation:

> 请通过 CLINX 查询本对话刚才派发的 Codex 任务，报告最新执行状态；如果已经结束，请读取并总结结果。不要重新派发任务。

ChatGPT uses the task context it already has to query CLINX and explain the
result. OP does not identify task IDs, pair conversations, create bindings,
configure Observer credentials, poll task status or send background messages.
The old task inbox and automatic identification/delivery code have been removed.
Existing local inbox files and Keychain entries are left untouched and unused.

The button requires a loaded conversation and an empty composer with no
attachments, visible modal or active generation. It preserves drafts and explains
why it cannot send. It disables while a query is being sent and verifies a new
matching user bubble; uncertain sends are never automatically retried. After a
finished query, another explicit click can query again. No private website API
is used. Night mode, reply protection, local copies and browser features remain.
Self-tests use an isolated app/profile and synthetic loopback conversations.

## WebKit fallback — 0.2.0

The following build instructions, features and earlier acceptance notes describe
the retained WebKit implementation. The existing Codex Run action still invokes
this fallback; use the explicit CEF commands above for the current backend.

Previously named ChatGPT Native. The app retains its original bundle ID and data paths.

Personal macOS client using Swift 6, SwiftUI and the system WKWebView. Loads
https://chatgpt.com/ directly, preserving its layout; no local server or OpenAI
API and no Electron/Chromium dependency.

Historical WebKit delivery: `/Applications/OP.app` 0.2.0 (3), local
ad hoc signature. Name/icon update accepted on 2026-10-19; see
`docs/BRANDING-OP.md`. The preceding 0.2.0 (2) delivery and data-retention
evidence remain in `docs/DELIVERY-0.2.0.md`.
Independent repository: `/Users/tinzleung/github/OP`.
Project: `ChatGPTNative.xcodeproj`, scheme `ChatGPTNative`, macOS 14+.
The internal Xcode project name and bundle ID remain unchanged to preserve existing data.

## Build and launch

Open the project in Xcode, or run:

```sh
./script/build_and_run.sh --verify
```

Build only: `./script/build_and_run.sh --build`. Other modes: `--debug`, `--logs`,
`--telemetry`. Run mode quits the existing app process before building.
Build output: `build/Build/Products/Release/OP.app`.

## Desktop features

- Shared persistent WKWebsiteDataStore; each window has independent navigation.
- Standard macOS Edit menu, file chooser/save sheets and JavaScript dialogs.
- WebKit download delegates; temporary sibling file followed by final move or
  replacement, preserving existing data if a transfer fails.
- Web-created popup windows retain WebKit's supplied configuration and opener.
- Menu-bar entry: Open ChatGPT, New Window, Quit.
- Opt-in native download notifications: Page > Enable Download Notifications.
- Native window resizing/full screen and standard Window menu.
- Camera/microphone purpose descriptions; no automatic permission grants.

| Shortcut | Action |
| --- | --- |
| Cmd-N | New window |
| Cmd-Shift-O | New chat in current window |
| Cmd-R | Reload |
| Cmd-[ / Cmd-] | Back / forward |
| Cmd-+ / Cmd-- / Cmd-0 | Zoom in / out / actual size |
| Cmd-C / Cmd-V / Cmd-X / Cmd-A | Native copy / paste / cut / select all |
| Cmd-W / Cmd-Q | Close window / quit |

Closing the last window keeps the app running for the menu-bar entry. Quitting
ends the process. Website data lives in the app's persistent WebKit store and
is isolated from the other installed ChatGPT apps and browsers.

## Local reply protection

The isolated WebKit observer reads rendered text on identified `chatgpt.com/c/…`
conversations. It never accesses cookies, credentials, private endpoints or page
application internals. Identified assistant replies are incrementally committed
to a separate SQLite store with SHA-256 fingerprints. The current verified site
profile does not expose stable user-message IDs, so user bubbles are skipped.
Unknown identity is never synthesized from position or text.

The page's `complete` turn state is recorded as **page ended, completeness
unverified**, distinct from confirmed complete, streaming and interruption.
No production DOM signal automatically certifies generation completeness. A
stopped spinner, quiet body, global announcement or page-ended state cannot prove
that the model delivered every intended token. Observed Stop actions remain
interrupted across subsequent reads. Stable page-ended text receives the same
overwrite protection as confirmed complete text.

Blank nodes, known error placeholders and read failure cannot replace saved
text. Complete text is retained when the same ID presents different text; the
local view exposes the alternate copy. This is protective storage, not a fix for
the unconfirmed upstream disappearance fault. It cannot protect undelivered text.

Use **本地副本 > 查看本地回复…** (`Cmd-Shift-L`) for an explicitly labeled native
recovery view. Recent cached conversations are also available in that menu.
Use **本地副本 > 查看保护状态…** for capture availability, current page state,
saved-reply count and actual errors. Informational states do not overlay the
chat; actionable read errors use a rounded, dismissible native notice with recovery
and retry actions. Closing the notice keeps the recorded error and local copies;
the protection-status and local-copy menus remain available.
Each window retains at most three WebViews in a stable native container; native
recent-conversation menu selections reuse mounted warm views. Memory pressure
releases inactive views, preserving the active one. Website sidebar navigation
remains the official SPA behavior and does not use this native selection pool.
Window activation and SwiftUI updates do not request a reload. Cold selections
show a labeled native local reply view while the official page loads. The first
window after restart restores the website silently; it does not automatically show
a local preview or manager. Saved replies remain available from the local-copy menu. Handoff requires observed conversation identity and a
usable reply body; this does not certify server completion or complete history.
A local copy is never injected into or sent back to the official page.
See [cache performance acceptance](docs/CACHE-PERFORMANCE-ACCEPTANCE.md) for
measurements, blocked comparisons and remaining limits. The 0.2.0 WebKit baseline
was subsequently retained as a rollback when the CEF delivery was installed.

Store: `~/Library/Application Support/local.personal.ChatGPTNative/Snapshots/replies.sqlite`.
This is local plaintext with owner-only directory/database permissions, separate
from the persistent default WebKit store. Local copies can span login periods;
they are not an account-synchronized archive. Retention: 30 days, 200 conversations,
64 MiB logical stored records, 500 newest messages per conversation, 1 MiB per
message and 2 MiB per observation. Oversize/unidentified content is not captured;
tool cards, images, attachments and branch identity are not fully archived.

**清除本地快照…** deletes these copies and pauses capture to prevent immediate
recreation; explicitly enable capture to resume. It never clears website data or
signs out. Deletion is logical SQLite cleanup, not a forensic secure-erasure claim.

Run `./script/test-protection.sh` for actual WKWebView synthetic integration plus
SQLite and separate-process restart tests. Outputs stay under ignored `build/`.
See `docs/PROTECTION-ACCEPTANCE.md` for the live-site gate and measured limits.

## Verified behavior and limits

The 0.1.0 acceptance exercised real account login, repeated quit/relaunch persistence, chat response, history,
file upload/read, blob download/save, multiple windows, reload and copy/paste
behavior. See `docs/ACCEPTANCE.md` for that baseline and
`docs/PROTECTION-ACCEPTANCE.md` for the 0.2.0 protection evidence and limits.

No Cloudflare challenge appeared in the 0.1.0 acceptance; later Chrome testing
was blocked by Cloudflare and was not bypassed. Finder
drag/drop, menu-bar click recovery, Spotlight UI launch, camera/voice, alternative
OAuth providers and all remaining website features have not been fully tested.
Native download notifications are implemented; official website Web Push is
not bridged. OS logs confirm notification delivery to history, while banner
presentation was muted by the system's screen-sharing/focus policy.

This is for local personal use, not a notarized distribution package. Existing
ChatGPT/ChatGPT Classic applications are preserved. No browser fingerprints,
security checks or cookie imports are modified.


## Targeted recovery UI checks

The Reply Protection test host has its own white repeat-arrow icon; the main OP
icon is unchanged. `./script/test-protection.sh --stress` opens a synthetic long
transcript in the real recovery sheet. `--notice` and `--notice-dark` exercise the
production notice component with a synthetic native read-failure state (not a
live HTTP failure). These interactive modes do not replace the normal test suite.
See [UI stability acceptance](docs/UI-STABILITY-ACCEPTANCE.md) for the scope,
CPU evidence and unconfirmed production-hang cause.

Icon sources: `script/make-protection-icon.swift`; generate a standard `.iconset`
folder, package with `iconutil -c icns`, and use `icon_512x512@2x.png` as the preview.
Icon resources are under `Tests/Resources/`.


## Scroll capture overhead

Message observation ignores unrelated DOM updates, reuses unchanged rendered
message text and error checks, and avoids re-serializing all unchanged replies.
DOM text, node replacement, visibility and identity/state changes invalidate the
relevant cache; pre-send/stop/pagehide flushes still run. The cache keeps only the
current accepted observation (up to 500 nodes / 2 MiB of rendered text).
`script/measure-scroll.sh` records test-only collect time and rAF intervals; these
are not physical trackpad/display measurements. See
[scroll and startup acceptance](docs/SCROLL-STARTUP-ACCEPTANCE.md) for results and
remaining official-page rendering limits.
