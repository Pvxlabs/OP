# ChatGPT Native 0.2.0

Personal macOS client using Swift 6, SwiftUI and the system WKWebView. Loads
https://chatgpt.com/ directly, preserving its layout; no local server or OpenAI
API and no Electron/Chromium dependency.

Accepted installed baseline: `/Applications/ChatGPT Native.app` 0.2.0 (2), local
ad hoc signature. Local delivery accepted on 2026-10-19; see
`docs/DELIVERY-0.2.0.md` for installation, data-retention and UI evidence.
Project: `ChatGPTNative.xcodeproj`, scheme `ChatGPTNative`, macOS 14+.

## Build and launch

Open the project in Xcode, or run:

```sh
./script/build_and_run.sh --verify
```

Build only: `./script/build_and_run.sh --build`. Other modes: `--debug`, `--logs`,
`--telemetry`. Run mode quits the existing app process before building.
Build output: `build/Build/Products/Release/ChatGPT Native.app`.

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
chat; actionable read errors retain a single recovery entry.
Each window retains at most three WebViews; warm selection reuses the same view.
Window activation and SwiftUI updates do not reload it. Restart opens the most
recent saved conversation and immediately offers its local text while the official
page loads. A local copy is never injected into or sent back to the official page.

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
