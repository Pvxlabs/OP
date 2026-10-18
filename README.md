# ChatGPT Native 0.1.0

Personal macOS client using Swift 6, SwiftUI and the system WKWebView. Loads
https://chatgpt.com/ directly, preserving its layout; no local server or OpenAI
API and no Electron/Chromium dependency.

Installed app: `/Applications/ChatGPT Native.app` (local ad hoc signature).
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

## Verified behavior and limits

Real account login, repeated quit/relaunch persistence, chat response, history,
file upload/read, blob download/save, multiple windows, reload and copy/paste
were exercised. See `docs/ACCEPTANCE.md` for precise evidence and limitations.

No Cloudflare challenge appeared; challenge completion is unverified. Finder
drag/drop, menu-bar click recovery, Spotlight UI launch, camera/voice, alternative
OAuth providers and all remaining website features have not been fully tested.
Native download notifications are implemented; official website Web Push is
not bridged. OS logs confirm notification delivery to history, while banner
presentation was muted by the system's screen-sharing/focus policy.

This is for local personal use, not a notarized distribution package. Existing
ChatGPT/ChatGPT Classic applications are preserved. No browser fingerprints,
security checks or cookie imports are modified.
