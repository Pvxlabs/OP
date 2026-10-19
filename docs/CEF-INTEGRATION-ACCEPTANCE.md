# CEF integration candidate acceptance — 2026-10-19

## Repository integration and local artifact cleanup — 2026-10-20

This delivery integrates the night appearance and CLINX original-chat changes on
master. The final 81 core + 4 restart checks and installed release hashes remain
the runtime validation evidence; the delivery step changes documentation only.

Local recovery and raw evidence use this archive:
`/Users/tinzleung/Developer/Archives/OP/2026-10-20/integration-032610`.
`recovery-apps.tar.gz` retains eight historical signed apps, with identical file
payloads stored using portable tar hard links. `recovery-manifest.json` records
SHA-256, modes and symlink targets; restore verification checks all eight apps.
The archive README provides extraction commands. No account, profile, Keychain or
CLINX service state is part of cleanup.

After verifying the pushed source commit/tree, cleanup removes superseded test
builds, temporary candidate apps, the duplicate compressed SDK download and Xcode
intermediates. The installed /Applications/OP.app, final CEF build, extracted CEF
SDK and local signing helper remain. Raw logs/screenshots/test runs are archived;
compatibility symlinks retain their documented build evidence paths. The local
archive's cleanup-report.json records actual removals and final repository state.

## Automatic CLINX identification and top-bar collection — 2026-10-20 — PASS

Installed /Applications/OP.app now places 收取 beside refresh in the native
40-point night-aware header. Ordinary original ChatGPT conversations remain the
source and destination. No conversation pairing or per-task ID entry is required;
manual binding fields are collapsed under Advanced.

`build/CEFIntegration/evidence/run-20261020-031706`: **81 core + 4 restart PASS**.
Real CEF covers AI source identification -> Observer exact execution verification
-> automatic binding -> result receipt -> assistant response without a manual
bind call. A real-site long-message collapse issue was corrected by excluding
Show more/less controls from full immutable-payload readback; the fixture now
exercises collapsed identity-query bubbles. Multiple new source turns in one
poll are each identified once; same-execution selections retain one binding.
The expanded test harness allows 180 seconds so it keeps its local fixture alive
for the additional source chat and bounded shutdown waits.

Real ordinary-chat evidence is separate and positive: the original work chat
identified its existing ORION P1.6 execution from actual tool context; Observer
verified the task/execution; explicit top-bar 收取 imported its historical terminal
result without ID entry; the result appeared in that same original chat and
ChatGPT responded. Automatic mode had correctly skipped replay before the
explicit historical collection. A capability-only test turn returned an empty
identity list and created no binding. The old MCP outage cleared on a fresh
read-only capability query. No new execution or service change was performed.

AI identifies the source; Observer verifies task/execution identities and does
not independently certify ChatGPT provenance. Source chats must be open/readable
for identification and delivery. This result does not resolve the existing
fresh-first-turn DOM identity, distribution or benchmark gaps, and it does not
certify the underlying ORION task's business qualification.

Strict deep local signing and three installed-file hashes passed; backup and
screenshots are under build/clinx-auto/. See [the automatic identification
contract](CLINX-AUTO-BINDING-SPEC.md) for exact gates and evidence. Earlier acceptance
entries below describe their respective historical builds.

## CLINX original-chat delivery update — 2026-10-20

The installed CEF build adds 页面 > CLINX 任务收件箱. An explicit task/execution
binding receives only the matching Observer result summary and submits a visible
follow-up in the bound ordinary ChatGPT conversation. Native Monitor credential
access and a real 50-task list read passed. A separate real ordinary test chat
received one synthetic receipt automatically and replied OP_CLINX_DELIVERY_ACK
in that same conversation; adapter readback returned responding.

Latest regression: `build/CEFIntegration/evidence/run-20261020-022257`, **66 core +
4 restart checks PASS**. The complete Observer HTTP -> durable inbox -> original
CEF conversation -> receipt -> response chain is synthetic fixture proof; live
Observer access and the real website adapter were checked separately. Current
website composer, submit button and user-message structure were diagnosed and
reflected in the fixture. No real task result was sent to an unrelated test chat.

Validated executable, native library and delivery script hashes match the installed
`/Applications/OP.app`; strict deep signing passed. Old app bundles are recoverable
under `build/clinx-delivery/`. The original ordinary work conversation and night
appearance were restored. See [the bounded implementation contract](CLINX-REPLY-SPEC.md)
for gates, uncertain-send handling and evidence paths. This update does not resolve
the previously recorded fresh-first-turn protection or distribution/benchmark gaps.

## Night mode update — 2026-10-20 — PASS

The fixed-light header is superseded by 页面 > 外观: 跟随系统 (default), 浅色,
夜晚. The preference persists and controls all native windows and recovery UI.
Light uses #F9F9F9 / #313131; night uses #1C1C1C / #EEEEEE. The refresh button is
borderless, avoiding accessory-bar vibrancy over a mismatched background; inactive
titles retain readable contrast. Header height remains 40 pt. Website styling is
not injected; pages following the system may respond to the native appearance.

`build/CEFIntegration/evidence/run-20261020-013153`: **38 core + 4 restart checks
PASS**, including native dark/light/system transitions, persisted selection,
multiwindow appearance, inactive title/refresh colors and preserved conversation
without navigation. Actual UI menu switching and a quit/relaunch confirmed night
mode persistence. Release compilation and strict local ad-hoc signing passed,
using the same signing approach as the existing installation; no developer signing
identity is currently available on this Mac.

Updated `/Applications/OP.app`, retained its bundle/data identity, selected 夜晚,
and verified the installed executable/native-library hashes match the staged
candidate. Actual installed-window AX/screenshot checks confirm the restored
conversation and visible refresh control; clicking refresh retained the restored
page. Evidence: `build/night-delivery/OP-night-installed.png` and `bundles.json`.
Old bundles are retained under `build/night-delivery/`. Earlier delivery and
acceptance statements below are historical. This targeted update does not resolve
the previously recorded first-turn identity or other product-acceptance gaps.

## Delivery state

Subsequent user-authorized installation: the user explicitly requested direct replacement. The CEF Release was packaged as **OP** and installed at `/Applications/OP.app`, retaining `local.personal.OP.CEFIntegration` so its existing CEF login/profile, defaults and SQLite remain in place. The original WK app and consistent SQLite backups are in `~/Library/Application Support/OP/Backups/InstallCEF-20261019-122333`. There was no Cookie migration, Git commit or push. The older isolation-only statements below describe the earlier gate and are superseded only for installation, not for outstanding functional/performance acceptance.

Owner acceptance update: after the final installation/header refinements, the owner confirmed that the new OP works correctly. Everyday/window UI acceptance is **PASS** based on that direct feedback. This does not certify the unresolved first-turn identity edge, exact frame performance, every file/OAuth flow or notarized distribution. The subsequent source-baseline/public-repository task is separate from this runtime acceptance record.

Latest header refinement: active title and bold refresh symbol are #313131; inactive title uses alpha 0.4. The refresh button uses native accessoryBarAction and showsBorderOnlyWhileMouseInside. Title/refresh layout anchors are shifted visually down 2 pt; native standard window controls use their original frames with a 2 pt right/down offset, reapplied on window resize without accumulating offsets. Full-screen control placement remains system-managed. Height remains 40 pt and background #F9F9F9. Release and strict signing pass. Candidate screenshots show active/inactive title appearance; installed-app automation is BLOCKED by stale app resolution/AX timeout, so exact installed hover and full-screen appearance are not claimed as passed.

Install-time snapshot verification: every original CEF message ID, primary body and fingerprint is preserved (9 records), and all 50 WK records remain exact. One CEF alternative-body field changed during ordinary post-launch webpage observation; the prior value remains in the consistent pre-install backup. This existing merge behavior was not modified or investigated further during the header/install task. Detailed metadata-only results are in `build/CEFIntegration/evidence/install-record.json`.

Isolated candidate: `build/CEFDelivery/Release/OPCEFIntegration.app`, display name **OP CEF Validation**, bundle ID `local.personal.OP.CEFValidation`, Apple Silicon Release, CEF/Chromium versions pinned in `Integration/CEF/version.lock.json`. No installation cutover, Git commit or push was performed.

The original prototype and the integration instance now used for work were preserved. The final candidate uses a separate profile, defaults and snapshots. All 60 pre-existing versionable files in `build/CEFIntegration/evidence/entry-files.json` still match their entry SHA256 values. The installed OP executable SHA256 remains `d477740b8e8279759e7d151444cb33ba94f21914a2609fa0a2f272169fad455d`.

## Final UI and startup — PASS

The latest instruction is **40 pt**, superseding 48 pt. Native `NSWindow.frame.height - contentLayoutRect.height` measured **40.0 pt** in the running Release test; background sRGB is **249/255** for every channel. Native AppKit window controls remain system-owned. The title has no bezel, background capsule or shadow. A single borderless `arrow.clockwise` refresh button is at top right, with CmdR retained. Native AX and actual screenshots confirmed the title/button and a visible official ChatGPT homepage; clicking refresh retained a working homepage. This UI interaction is not a captured HTTP request trace.

Startup selects the official browser without a local overlay, then refreshes the recent snapshot list. A restart test with existing SQLite content confirms `showingLocal == false` and `showRecovery == false`, including after official synchronization. Local restoration remains available explicitly in menus; cold user-initiated cached-conversation selection still uses identity-matched local content. AppKit owns window sizing (`NSHostingView.sizingOptions = []`). No official-page styles were modified.

Current host is macOS 26.6.2 with Xcode 27 SDK. macOS 27 appearance is **NOT_RUN**, regardless of SDK version.

## Regression evidence

Latest successful run: `build/CEFIntegration/evidence/run-20261019-121859`, **30 core + 4 restart checks PASS**. Reports are `core.json`, `restart.json`, `events.ndjson` and `process-samples.json`. The core suite took 15.497 s; restart suite 0.553 s. These are test durations, not website startup timings.

Coverage includes actual CEF renderer → isolated-world observer → shared SQLite ingestion; full synthetic text capture; same-origin iframe/main-world isolation; missing/mismatched conversation IDs rejected; blank/error/HTTP 403/429 observations preserve prior body; reload and handoff deduplication; stream stays unfinished; restart persistence; hot browser/NSView reuse; bounded three-entry LRU and memory-pressure eviction; multiwindow separation; capture pause; actual renderer crash retaining native window/prior body; renderer retry; unfinished stream marked interrupted on close.

`pageEnded` remains conservative and does not mean server-final. The shared store/model/library and WebKit implementation were not changed by this integration.

**Retained failure:** `run-20261019-121701/core.json` timed out before the first snapshot; events show about:blank/observer installation but no successful fixture navigation. A fresh run of the same candidate passed all 34 checks, and normal official-homepage launch succeeded. The intermittent first-navigation failure has **NOT CONFIRMED** cause and remains a stability risk; a successful rerun does not erase it. No production work window was refreshed to investigate it.

## Real website protection — partial PASS, formal replacement BLOCKED

In the earlier independently logged-in integration, a known synthetic existing official conversation and a subsequent new reply were saved with stable message IDs; local recovery displayed them and reopening retained login. These observations belong to that integration/profile, not to a migrated production profile or the fresh validation profile.

A fresh first-turn synthetic conversation exposed a real coverage gap: canonical URL had a valid new conversation ID, while the visible message's DOM conversation identity attribute was empty/invalid. Old hidden nodes retained a previous conversation ID and zero visible body length. The conservative identity gate correctly rejected ambiguous attribution, but this means the first visible reply was not protected until the canonical conversation was reopened and reliable DOM identity appeared. The DOM shape and skipped capture are confirmed; why the website leaves that attribute empty is NOT CONFIRMED.

The gate was not relaxed to URL-only attribution, no automatic refresh was added, and no unfinished body was relabeled complete. A separately designed, explicitly unassigned pending-copy policy or another directly verified identity mechanism is needed before claiming complete fresh-chat protection. This is a **BLOCKED** production-readiness item, not hidden by a passing synthetic fixture.

## Performance, memory and runtime limits

The user reported substantially better prototype scrolling; that qualitative result was reused without repeating the demo. There is **no matched real-workload before/after display-frame or total-process CPU/RSS benchmark** for the integrated candidate. Original WK peaks (138.7% interval CPU / 1336 MiB renderer RSS) cannot be compared to mixed synthetic-regression process samples.

The latest synchronous native hot selection measured **0.098709 ms**. This excludes page visibility/sync/display timing and is **not** end-to-end switch latency or FPS. Earlier mixed regression samples reached aggregate family RSS about **1056 MiB** across up to nine processes; `ps %cpu` is lifetime average, not interval scrolling CPU. Generic helper processes can host GPU roles, so role-specific GPU costs were not established.

Physical bundle size measured approximately **326 MiB**, compared with about **2 MiB** for installed WK OP. CEF adds a pinned runtime, nested helpers, signing and security-upgrade maintenance. Per-window LRU is bounded at three; no unlimited preloading was introduced. Global cost still grows with user-opened windows.

Renderer-crash recovery and clean synthetic process shutdown passed. GPU-process crash, hung-browser recovery, real upload/download/OAuth popup corner cases, real streaming-interaction workload, matched startup timing, long-duration stability and macOS 27 UI remain **NOT_RUN**. Local strict code-signature verification passed; Developer ID distribution, notarization/stapling and clean-host Gatekeeper acceptance are **NOT_RUN**.

## Preserved backup

`~/Library/Application Support/OP/Backups/CEFPrototype-20261019-113842` contains the accepted prototype app and its sources/build metadata, with 266 manifest entries matching and strict code-sign verification passing. Profiles, credentials, cookies and private chat logs were excluded. Do not run this backup concurrently with the original prototype because they retain the same original profile location.

## Conclusion

**PASS:** isolated CEF architecture/build/signing, final native 40 pt header, refresh entry, silent startup, bounded cache and synthetic protection/lifecycle regressions. **BLOCKED:** formal production replacement due to first-turn protection coverage and incomplete full product acceptance. **NOT_RUN:** controlled real performance gains and remaining platform/file/distribution acceptance above. Existing OP installation and current work instances remain unchanged.
