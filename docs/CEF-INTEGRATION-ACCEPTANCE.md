# CEF integration candidate acceptance — 2026-10-19

## Official webpage only and review cleanup — 2026-10-20 — Air 0.3.3

Normal startup, conversation selection, cold loading and HTTP failure now keep
CEF visible. Removed the automatic local transcript overlay and its snapshot
loading/selection/handoff state. Local copies remain in File > 本地回复副本…
(⌘L) and open only by explicit action. Selecting an official conversation
closes that recovery sheet. Snapshot capture/storage, the approved Figma header,
manual CLINX query and native reply reminders are retained.

Final synthetic regression: `build/CEFIntegration/evidence/run-20261020-062504`,
**70 core + 4 restart PASS**. Includes cold selections with/without snapshots,
HTTP failure, explicit recovery and return to CEF, plus existing capture,
header, query and native notification logic. A normal isolated fixture window
was also visually checked: the browser remains visible, ⌘L opens the local
copy sheet, and Close returns to the browser. This is fixture UI acceptance;
no new real ChatGPT message was sent for this change.

Cleanup exposed a recurrence: launching CEF re-registered its optional Alerts
helper after the system notification entry was reset. The build now omits that
helper and removes stale incremental bundle output before signing. Generic,
GPU and renderer helpers remain. OP reply notifications continue through the
native UserNotifications channel. See the
[CEF maintainer's guidance](https://www.magpcss.org/ceforum/viewtopic.php?f=6&t=20177).
The test runner disables web notification APIs during fixtures and now requests
a graceful quit of only its isolated review bundle if a run times out.

Air final replacement, relaunch and strict signing: **PASS**, **281 installed
file hashes** match the release and all **61 prior reply fingerprints** remain.
Bundle/data identity and Chromium profile are preserved. Final backup:
`~/Library/Application Support/OP/Backups/OfficialOnly-20261020-062730/OP.app`.
Local install/verification/cleanup receipts are under
`build/OfficialOnly-Air-20261020`.

Used System Settings' per-app Reset Notifications action to remove Air Review,
Query Review, old CEF Alerts entries and OPCEFPrototype. After the final
production launch, the actual notification settings UI and screenshot show
**only OP** among OP entries; its notification permission and sounds remain on.
No unrelated app preference, global notification database, Focus setting or
screen-sharing policy was changed. Known review/prototype LaunchServices
registrations are removed while preserving the apps/backups. Final process
inventory shows **zero review processes and zero fixture services**, both
temporary fixture listeners are closed, and the settings window is closed.
The installed app runs from `/Applications/OP.app`, version **0.3.3**.

## Background reply notifications — 2026-10-20 — Air 0.3.2

Scope: a locally observed ChatGPT reply finishing while OP is inactive sends one
macOS notification. Notification text is generic; no reply body is included.
Click handling activates the matching conversation. The Page menu can disable
reminders. Approved Figma header assets and layout remain unchanged.

`build/CEFIntegration/evidence/run-20261020-055908`: **64 core + 4 restart PASS**.
The nine new cases cover initial history, one background completion, duplicate
suppression, foreground completion, no foreground replay, manual stop, errors,
snapshot-independent detection and disabling reminders. Native bridge isolation
and the existing header/manual-query guards also pass. These tests inject a
notification sink; they do not prove system banner delivery or server finality.

An earlier isolated review run crashed in `runReplyNotifications()` because its
test dereferenced the active session before asynchronous creation completed.
The test now waits for the loaded conversation before using that session. The
owner-supplied 05:55:07 crash report matches this test frame and review bundle;
the installed production application had not been replaced at that point.
The complete fixed suite passed before production replacement.

Release build, strict deep signature and Air replacement: **PASS**. All **285
installed file hashes** match the release, all **61 prior reply fingerprints**
remain, and the original bundle/data identity and profile are retained. Backup:
`~/Library/Application Support/OP/Backups/ReplyNotifications-20261020-060451/OP.app`.
Receipts: `build/Reply-Notifications-20261020/installation.json` and
`post-launch-verification.json`. Installed version is 0.3.2.

Air notification permission was visibly off and is now **on**, with desktop,
Notification Center and sounds enabled. A normal isolated local fixture was
opened for OS delivery checks; its temporary notification permission was restored
to off and the review app quit afterwards. The system setting for mirrored/shared
screens suppresses notifications, and the computer-use service times out when
selecting Notification Center. Actual system banner appearance is **BLOCKED**;
notification-click UI and real ChatGPT completion acceptance are **NOT_RUN**.
No global Focus or screen-sharing policy was changed. The previous iMac 0.3.1
delivery record below remains separate from this Air update.


## Source publication and iMac update — 2026-10-20

Source delivery commit `6f4845ecc6f678b16a8707fdcfaea64a84a40143` was pushed
to public `origin/master`; remote SHA readback matched. Staged content scan
found no credential patterns, and `git diff --cached --check` passed. PDF and
OpenType header resources are marked binary without changing their bytes.
The unchanged application source retains the final **55 core + 4 restart PASS**
run and Air owner acceptance recorded below.

iMac updated from 0.3.0 to the same signed 0.3.1 artifact accepted on Air.
Transfer used only the private Tailnet, a temporary fixed-file server restricted
to the iMac peer, and a pre-verified archive SHA-256; the endpoint was stopped
after delivery. Existing remote device authorization was used; no SSH keys,
network ACLs, public endpoints or user credentials were added.

Staging, strict deep signature verification, backed-up replacement, relaunch and
post-launch file verification: **PASS**. All **284 files** match Air, all **46
pre-existing reply fingerprints** and both legacy inbox files remain. Existing
profile, bundle/data identity and Keychain are retained. Backup on iMac:
`~/Library/Application Support/OP/Backups/FigmaHeader-20261020-054647/OP.app`.
Spotlight reports the correct CEF identifier and the installed main process is
running from `/Applications/OP.app`. Local receipt:
`build/Publish-iMac-20261020/imac-installation.json`; iMac receipt:
`~/Library/Application Support/OP/Updates/Figma-20261020/installation.json`.
No new iMac real-site interaction or owner UI acceptance was claimed.

Air post-publication verification also retained **284 matching files** and all
**57 prior reply fingerprints**. The separate current computer-use service cache
limitation is described below; system registration repair and owner acceptance
must not be confused with a successful automation-service restart.


## Air owner acceptance and OP registration — 2026-10-20

The owner explicitly confirmed actual Air use of the installed Figma-matched
0.3.1 is correct. Installed everyday/header acceptance is **PASS** from that
feedback. This supersedes the prior product-acceptance uncertainty; it does
not claim that the separate automation resolver has been repaired.

Removed eight stale OP backup/build registrations from LaunchServices without
removing or modifying the backup apps. Re-registered `/Applications/OP.app`
and refreshed Spotlight metadata. A fresh NSWorkspace lookup selects that
installed path, the running process reports the same path, and Spotlight reports
`local.personal.OP.CEFIntegration`. Final registry has one registration for that
identity at the installed path. These native system checks are **PASS**.

`script/refresh-op-registration.py` repeats this narrow maintenance operation:
verify the installed signature/identity, unregister only known OP backup/build
copies, force-refresh the installed app and preserve backup metadata. It does
not reset the global database, modify signed app contents, or touch profiles,
reply stores or Keychain. Run it after replacing an installed bundle if needed.

The already-running computer-use service still maps the installed URL to the
retired WebKit identity; a new JavaScript session does not clear that service's
process-local mapping. Selecting the current build identity instead reaches a
separate AX timeout. This is **BLOCKED** only for that tool session; restarting
the owning automation client remains an external follow-up. Do not change OP's
persisted bundle/data identity to work around the tool's process cache.

Local metadata-only evidence is under `build/Publish-iMac-20261020`.


## Owner-edited Figma header — 2026-10-20 — Air

This delivery supersedes the earlier header styling and uninstalled inset/color
experiment. Implemented the actual exported vectors and coordinates from
“02 你的调整区” in Figma file `xWHKogXYl3WijpAvXxn7MP`.
Night uses #1C1C1C / #A1A1AA, exact square-checkmark collect glyph, and
#2E2E2E hover surfaces (32 x 30 pt, 4 pt corners, 4 pt gap, 12 pt right inset).
The inactive night design contains no right icons; both hide, and title is
#6E6E6E. Light active keeps its tray glyph and original drawn positions/colors.
Inter Bold 13 pt is bundled with its OFL license and registered per process.
Native traffic-light centers and title baselines follow the exported design.
No additional visual proposal was introduced.

Native pointer-over screenshots for both buttons, pointer exit, and light state:
**PASS**, under `build/Figma-Delivery-20261020/`. The first visual check caught
AppKit's 32 pt accessory clip view truncating the 30 pt hover surface at the
bottom. Disabling clipping on that accessory's immediate container preserves
the design and exposes all four rounded corners. AppKit still owns native
controls, hit/action behavior, accessibility and full-screen controls.

Final isolated real-CEF regression: **55 core + 4 restart PASS** at
`build/CEFIntegration/evidence/run-20261020-053437`. Includes exact windowed
geometry/font, inactive state, appearance switching without navigation, manual
query sending/guards, snapshot preservation, cache, crash and restart behavior.
Measured header 40 pt, button top 5 pt (design 5.002 pt raster-aligned), right
inset 12 pt, traffic-light first center (18.5, 19.5) pt. Initial 32 pt header
experiment failed that existing height check and was corrected before delivery.

Air release build, strict deep signing, backed-up installation and relaunch:
**PASS**. All 284 candidate/installed file hashes match; all 57
pre-existing reply fingerprints remain. Version stays 0.3.1, source is local
working-tree changes based on `5781150`. Backup: `/Users/tinzleung/Library/Application Support/OP/Backups/FigmaHeader-20261020-053602/OP.app`.
Receipt: `build/Figma-Delivery-20261020/installation.json`; post-launch
verification: `build/Figma-Delivery-20261020/post-launch-verification.json`.

Installed-window automation: **BLOCKED** by stale application registration
(`/Applications/OP.app` resolves to retired `local.personal.ChatGPTNative`;
bundle-ID resolution is ambiguous across retained backups). Running installed
process, exact bundle hashes/signature and data preservation were independently
verified. Screenshots are explicitly from the separate review app, and inactive
state is verified by native integration checks because per-app screenshot
capture activates the target. New production task dispatch/query and broader
website acceptance were **NOT_RUN** for this visual-only change.


## Header hover and inactive icon tint — 2026-10-20 — Air

Owner feedback confirms that the simplified manual query now works in normal
use ("方式 1 现在能正常使用了"). This supplies real-use acceptance for that flow,
separate from the UI automation timeout recorded below.

Both top-right controls are now icon-only, with equal 32 x 28 pt targets and an
8 pt gap. Tooltips and accessibility names remain. Both use the title's exact
active/inactive light/dark tint. A small borderless NSButton subclass paints a
6 pt corner-radius background on pointer entry and removes it on exit; pressing
uses a stronger fill. It preserves native target/action, disabled handling and
accessibility. A bordered accessoryBarAction was rejected after the real window
screenshot showed system-colored icons: the SDK documents contentTintColor as
applicable only to borderless buttons.

Actual pointer-over screenshots of both controls in the independent native CEF
test window: **PASS**, saved at `build/Header-Air-20261020/hover-refresh.png` and
`hover-collect.png`. Text is absent and title/icon colors match in the inspected
window. Final regression: `build/CEFIntegration/evidence/run-20261020-043220`,
**54 core + 4 restart PASS**, including muted inactive icon/title equality in
light and night modes, query sending, protection, cache and restart. The earlier
`run-20261020-042923` failure retained an obsolete expectation that the night
refresh icon stay bright even when inactive; it was replaced with the requested
icon/title equality while retaining the exact dark-background and inactive-title
color checks. No behavioral protection was dropped.

Air installation/relaunch, strict deep signing and **273 candidate/installed file
hashes: PASS**. All **53 pre-existing reply fingerprints** remain. Version stays
0.3.1; prior build backup is
`~/Library/Application Support/OP/Backups/HeaderHover-20261020-043359/OP.app`.
Receipt: `build/Header-Air-20261020/installation.json`.
The installed work-chat UI resolver still reaches an accessibility timeout;
the hover screenshots above are explicitly from the independent test window.


## Simplified manual CLINX query — 2026-10-20 — Air 0.3.1

This delivery supersedes the automatic identification/inbox behavior described
below. 收取 now submits one fixed ordinary message in the currently loaded chat:

> 请通过 CLINX 查询本对话刚才派发的 Codex 任务，报告最新执行状态；如果已经结束，请读取并总结结果。不要重新派发任务。

Removed the identifier, pairing/binding/inbox UI and persistence implementation,
Observer/Keychain client, polling, automatic result delivery and their obsolete
fixtures/tests. Existing data/credentials are not deleted. Night mode, native
chrome, browser controls, local snapshots/recovery and CEF lifecycle remain.

Validation: `build/CEFIntegration/evidence/run-20261020-041842` reports **54 core
+ 4 restart PASS**. The native button is actually clicked in the real CEF fixture;
it disables during send and opens no inbox/window. A later explicit repeat
submits the same message again. Drafts, active generation, modal dialogs and
attachments block sending. Concurrent requests, disabled submit, user edits,
new modals, navigation during insertion and missing readback are covered without
automatic retry. The query succeeds without assistant-message capture identity.
No Observer `/v1/` request occurs. Existing appearance (including inactive windows),
cache, snapshot integrity, crash recovery and restart checks pass. The earlier
85-check total included the removed feature; it is historical, not the current
acceptance count.

Release and strict deep signing: **PASS**. Installed `/Applications/OP.app` is
0.3.1, retains `local.personal.OP.CEFIntegration`, and all **273 file hashes**
match the release candidate. The removed `ClinxDelivery.js` is absent; the new
`ExecutionQuery.js` is packaged. Graceful quit, backup, replacement and relaunch:
**PASS**. All **51 existing reply fingerprints** are preserved after launch.
Air had no legacy inbox files. Backup:
`~/Library/Application Support/OP/Backups/ManualQuery-20261020-042009/OP.app`,
with a consistent local SQLite backup beside it. Installation receipt:
`build/Query-Air-20261020/installation.json`. Source is the local working tree
based on `5781150`; this delivery did not publish a new Git commit.

Installed real-chat UI acceptance: **BLOCKED**. The installed-path UI resolver
still selects the old WebKit identity; resolving via the current CEF build path
reaches an accessibility timeout. Targeted LaunchServices re-registration did
not resolve it. No real task was dispatched/continued/cancelled for testing;
no production ChatGPT query result is claimed. The successful native-button
fixture and installed process/hash checks are separate from this UI gate.


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


## 2026-10-20 shared light/night header, Air 0.3.4

The owner authorized Air validation after iMac remained locked. Light mode now
uses the approved night traffic-light/title/icon positions and glyphs. Both
appearances hide right icons when inactive, use a #6E6E6E inactive title and
retain the 4 pt hover corners. Existing active palettes remain unchanged.

- PASS: isolated Air fixture run, 72 core checks and 4 restart checks.
- PASS: visual inspection of six AppKit header render captures from the running
  candidate (light/night, focused/unfocused/hover), including inset rounded hover
  backgrounds and matching native geometry. These are native view renders,
  not desktop screenshots.
- PASS: Air /Applications/OP.app 0.3.4 replacement, 281 file hashes match the
  release build, strict deep signing, 71 existing reply fingerprints preserved.
  A rollback app and consistent SQLite backup were retained locally.
- PASS: test/fixture processes stopped, fixture/transfer listeners closed, review
  copies unregistered; System Settings shows only the formal OP notification
  entry, with its existing sound/banner preferences retained.
- BLOCKED: installed formal-window desktop automation. The visual tool resolves
  obsolete OP app identities or times out; an attempted name lookup selected a
  review app, which was closed and its notification entry removed. This is not
  a formal installed-window visual acceptance.
- PASS: owner-authorized iMac update to the identical 281-file Air 0.3.4 bundle,
  strict deep signing and launch; all 46 previous reply fingerprints and 2 legacy
  inbox files preserved, with the prior app and consistent SQLite backup retained.
- NOT_RUN: unlocked iMac desktop visual review.

Local evidence: build/LightHeader-Air-20261020 and isolated fixture evidence
run-20261020-065901. Publication and cleanup receipts are under
build/Publish-034-20261020. Redundant build caches and transfer archives were
recycled after live-file checks; installed data, SDK, rollback apps and evidence
were retained. Raw account data and bundle artifacts remain untracked.


## 2026-10-20 query confirmation correction — iMac

The installed application reported an uncertain send even though its fixed query
and a following assistant reply were visible. Readback required both a layout
box on the user wrapper and an increase in the count of identical visible queries.
A `display: contents` wrapper has rendered content without its own box; removing
an older query as a new one arrives also leaves that count unchanged. Readback
now checks rendered contents and newly observed message keys. Re-rendered history
with the same keys cannot confirm a send. No send retry or alert suppression was
added; missing/hidden receipts, changed conversations and protected drafts remain
conservative failures.

The old implementation failed the real CEF display-contents regression after
52 passing checks in `build/CEFIntegration/evidence/run-20261020-205714`.
The corrected pre-sync build passed 75 core and 4 restart checks in
`build/CEFIntegration/evidence/run-20261020-210441`, including native-button
submission, replacement of an older identical bubble, hidden receipts and
re-mounted history without a new receipt. The test harness now explicitly waits
for its window to gain focus before asserting active-header colors.

The repository was subsequently fast-forwarded to `ce33b46`, preserving its
consultation preflight and transport changes; query fixture controls use separate
numbers from the new transport controls. Final latest-baseline validation and
installation evidence follow.

Live-site scope: read-only diagnostics and restored-window review. The original
page reported zero wrapper rectangles before restart; its reloaded wrappers were
ordinary visible blocks. The exact transient CSS state at the original click was
not captured, so the fixture reproduction is not presented as proof of that
particular live DOM state. No new query was sent into a real work conversation.


Latest-baseline evidence: `build/CEFIntegration/evidence/run-20261020-210713`.
The query/protection/appearance/notification checks passed; the full core run
recorded 85 passing checks before the upstream transport cancellation assertion
failed. Its expected Chromium error is -3, but this iMac reports -2 at cancellation
with UR_FAILED and HTTP 200. A transport-only repeat in
`build/CEFIntegration/evidence/run-20261020-210918` reproduced the same mismatch.
This unrelated assertion/runtime distinction was left unchanged. A separate run
of the latest package against the same synthetic SQLite store passed all four
restart checks. The entire latest core suite is therefore FAIL, not all-pass.

Release build and strict deep Apple Development signing passed on iMac after
installing Apple's public WWDR G3 intermediate certificate through its normal
trust chain. No private key was transferred. Final installation has 283 matching
candidate file hashes and preserved all 141 prior reply fingerprints. Receipt:
`build/query-confirmation-transfer/final-installation.json`. Original rollback:
`~/Library/Application Support/OP/Backups/QueryConfirmation-20261020-210100/OP.app`;
the intermediate installation is also backed up beside it. The installed app
restored the original conversation with no sheet. Immediately before the final
update, native accessibility reported the real button tooltip as 查询已发送；再次点击可重新查询执行情况
following a user-initiated query; automation did not send that query.

Air was used only for an initial isolated signing attempt before the iMac
certificate chain became available. Its checkout and installed app were untouched;
this run's temporary transfer directories and listeners were removed/stopped.

## 2026-10-21 query readback provenance audit and publication

The seven remaining dirty files originate from the local task
“同步仓库并修复异常弹窗” on 2026-10-20. Its user request, recorded edits and final
report agree with the entry patch and SHA256 manifest preserved before the
long-conversation investigation. Commit `1560b31` deliberately excluded those
changes; this follow-up is separately authorized for commit and push.

- `ExecutionQuery.js`: recognize visible `display: contents` contents and new
  matching search-unit keys instead of requiring a higher identical-message count.
- `ExecutionQueryTests.swift` and `fixture.py`: cover contents wrappers, old-query
  removal, hidden receipts and history remounts without a new query.
- `IntegrationTests.swift`: make the isolated test window active/key before
  checking focused header appearance; no production focus policy changes.
- `Runtime.mm`: add display/rendered-child layout metadata to the existing manual
  message diagnostic; it neither submits queries nor changes page layout.
- The SPEC and this acceptance record state the readback contract and preserve
  historical build, installation and failure evidence.

Historical records were checked directly: `run-20261020-205714` failed the
contents-wrapper case after 52 checks; `run-20261020-210441` passed 75 core and
four restart checks. On the later baseline, `run-20261020-210713` failed after
85 checks at the unrelated transport-cancellation assertion; the query cases
passed. The 2026-10-21 `run-20261021-111529` record passed 95 core/four restart
checks with these original changes present. This does not erase the earlier
failure or establish that cancellation behavior is fixed.

Audit found one missing negative case: for role-only user nodes without a stable
search-unit key, the proposed fallback used the DOM node object as identity.
Cloning/remounting old matching history could therefore report `sent` with no new
query receipt. The isolated reproduction in
`build/remaining-changes-audit-20261021/source/build/CEFIntegration/evidence/run-20261021-121134/`
failed the expected-uncertain assertion and recorded `roleOnlyRemountReportedSent=1`.

The follow-up removes that fallback from confirmation: only a nonempty stable
supported message key absent from the pre-send set can confirm a query. Unknown
identity remains uncertain; no automatic retry is added. The new real-CEF
regression remounts role-only history without producing a new receipt. Original
seven-file sources and patch remain in `build/remaining-changes-audit-20261021/`.

Final validation: Release build and strict deep signing PASS; full core 97 checks
and restart four checks PASS. Evidence:
`build/remaining-changes-audit-20261021/source/build/CEFIntegration/evidence/run-20261021-121358/`.
The new role-only-remount assertion and all original query guards pass. The
historically unstable cancellation assertion also passed this run, unchanged;
this is not a cancellation-path repair. The local test runner allowed 240 seconds
instead of 180 for the full core phase because the diagnostic probes add two
30-second sampling windows. No assertion was weakened or skipped, and the
repository runner's limit remains unchanged.

All testing uses a separately identified synthetic CEF app, mock keychain and
isolated profile; no real work query is submitted. This publication does not
replace or restart the installed OP app; the new missing-key guard requires a
subsequent app build/install to become active in the user's running app.


## 2026-10-22 explicit queries during generation

The user removed the generation-idle requirement for explicit query clicks.
`ExecutionQuery.js` no longer scans streaming/turn markers or rejects an explicit
query before or during insertion because ChatGPT is generating. It uses the
webpage's available send/queue control, excluding Stop controls even when they
are submit buttons. Drafts, attachments, modals, conversation identity, duplicate
click protection and stable new-message confirmation keep their existing behavior.
Unavailable sends remain drafts and uncertain sends are never automatically retried.

The isolated signed Release passed 99 core checks and four restart checks:
`build/CEFIntegration/evidence/run-20261022-041005/`. The new cases verify sending
with streaming turn metadata, a visible Stop control beside a queue control, and
generation beginning during text insertion. The queue fixture only acknowledges
a query while the original turn remains in progress. This proves the real CEF
DOM/native flow against a synthetic page; live ChatGPT queue acceptance is not
claimed. Tests use a separate bundle/profile and their native windows close on exit.
Build/signing logs and the source before-image are under
`build/query-during-generation-20261021T200925Z/`.

The production-identity Release also built and passed strict deep signature
verification. On iMac, `/Applications/OP.app` was backed up, normally quit,
replaced and relaunched. Installed executable, native library, Info.plist and
query resource hashes match the signed candidate; the query resource SHA256 is
`29ab45cbec91d23b072a2bd582fe274967acdf4183a42f566c10acd20a0d7060`.
See `installation-receipt.json` and `rollback-receipt.json` in the task evidence
directory. No ChatGPT query or CLINX execution was dispatched for live acceptance.
