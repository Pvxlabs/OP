# CEF integration candidate acceptance — 2026-10-19

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
