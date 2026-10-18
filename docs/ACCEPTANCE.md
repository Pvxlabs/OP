# Acceptance — 2026-10-19

Release: 0.1.0 (1). Final installed version is running from /Applications.
Overall: core MVP PASS; complete feature parity and formal full acceptance PARTIAL.

| Requirement | Status | Evidence / limit |
| --- | --- | --- |
| Independent Xcode project | PASS | Separate Git repository /Users/tinzleung/github/ChatGPTNative |
| Swift 6 release build | PASS | Xcode 27.1 / Swift 6.4; docs/build.log: BUILD SUCCEEDED |
| Real native launch / official UI | PASS | Installed bundle process; observed chatgpt.com official UI in native window |
| Existing account login | PASS | User signed in directly; logged-in profile/composer/history observed |
| Cloudflare challenge | NOT_RUN | No challenge encountered; no challenge pass claim |
| Login persistence | PASS | Normal Cmd-Q and installed-bundle relaunch; login/history retained, repeated after final update |
| Basic chat | PASS | Synthetic test prompt received CHATGPT_NATIVE_OK |
| History | PASS | New test conversations appeared in history and reopened after relaunch |
| Upload | PASS | NSOpenPanel selected fixtures/acceptance.txt; upload completed; model read CHATGPT_NATIVE_UPLOAD_OK |
| Download | PASS | Actual mouse click triggered blob download, NSSavePanel, saved file; bytes compared locally |
| Final download implementation | PASS | acceptance-download-final.txt: 126 bytes, byte-identical to fixture; no .chatgpt-*.download files left |
| Existing-file replacement / failed-transfer protection | NOT_RUN | Implemented staging then replace/move; not separately fault-injected |
| Multiple windows | PASS | Cmd-N created chat-AppWindow-2; closing it returned to original conversation in window 1 |
| Reload | PASS | Cmd-R caused native navigation start/finish and returned to same conversation |
| Copy / paste | PASS | Synthetic text copied, deleted, pasted back unchanged; test draft cleared |
| Other page shortcuts / window resize | NOT_RUN | Native commands / resizable scene present; not individually exercised |
| Menu-bar quick launch | NOT_RUN | MenuBarExtra implemented; automation could not expose menu extras for click/recovery proof |
| Finder drag/drop | NOT_RUN | Default WebKit behavior retained; actual Finder-to-app gesture not verified |
| Native download notification submission / history | PASS | Authorization requested through native UI; usernoted/NotificationCenter logs accepted and stored actual download notification |
| Notification banner | BLOCKED | OS log: muted by display state (displayShared), focus policy delays delivery; system settings left intact |
| Official webpage Web Push | BLOCKED | No public WKWebView integration established; no private API or DOM notification replacement added |
| Camera / microphone / alternate OAuth / popup flows | NOT_RUN | Usage declarations and public popup/dialog support provided; no complete website parity claim |
| Installation / signature | PASS | /Applications/ChatGPT Native.app; ditto; codesign --verify --deep --strict |
| Installed independent launch | PASS | Process path /Applications/ChatGPT Native.app/Contents/MacOS/ChatGPT Native |
| Spotlight indexing | PASS | mdfind returns installed bundle; mdls reports bundle identifier/display name |
| Spotlight UI search + launch | NOT_RUN | Spotlight UI access timed out through automation; indexing alone is not UI acceptance |
| No local server / extra browser runtime | PASS | Direct HTTPS load; system WebKit; no third-party dependencies |
| Existing work preserved | PASS | CLINX git status clean; existing apps untouched |

Fixture and both downloads SHA-256:
201ccaf3daaf30b414b651de99fe5eefa8ebd8e23e95d556e01b198da34094a7

## Evidence boundary

Raw `docs/build.log` and `docs/runtime-evidence.log` are local-only evidence,
ignored by Git and excluded from the v0.1.0 source baseline. This document
retains the acceptance summary; the baseline does not assert full acceptance.

Native AX snapshots and screenshots were inspected during execution; personal
history/account content was not exported into this repository. Runtime evidence
records only navigation schemes, hosts, MIME types, event names and numeric
errors. The model's own claim of file equality was not used as proof: local byte
comparison after actual download established equality.

Accessibility-triggered clicks initially failed to trigger the file-download
gesture. Actual mouse-coordinate click produced WebKit blob download=true and
native save sheet. No website workaround or fingerprint change was needed.

Notification diagnostics at 03:25:39–03:25:40 execution-host time showed successful
submission, delivery and history storage, then displayShared muting. Times are
raw host evidence; the report date uses Asia/Shanghai. Full raw OS notification
logs are not retained because they include unrelated system identifiers.

Xcode emitted CoreDevice/CoreSimulator environment diagnostics; the macOS
release build succeeded. No unrelated Xcode installation repair was attempted.
