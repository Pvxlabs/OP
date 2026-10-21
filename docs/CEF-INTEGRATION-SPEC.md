# OP CEF isolated product integration

Status: after isolated validation, the user explicitly requested direct replacement. CEF is now installed as /Applications/OP.app using the existing CEFIntegration data identity, with the WK app/data retained for rollback. First-turn DOM identity coverage and remaining product-acceptance gaps are still unresolved; installation does not establish those checks as passed. See CEF-INTEGRATION-ACCEPTANCE.md.

## Contract

Create an Apple Silicon Release target in Integration/CEF using the already pinned CEF distribution. Keep all existing WebKit source, Xcode target, dirty work and installed bundles intact. Skip Linear as explicitly directed earlier in this thread. No commit, push or data migration/cookie export.

Native AppKit owns NSApplication and CEF's main loop; SwiftUI owns per-window state, local recovery and panels. A narrow C ABI hosts windowed CEF NSViews. Native unified toolbar follows the supplied Codex reference and subsequent refinement: system traffic lights and title only, with a 40 pt title area. Only a native refresh icon at top right; no other custom titlebar buttons, title capsule or shadow. Native titlebar accessory displays plain text; titlebar background is #F9F9F9. Back/forward, recent local copies, protection and new windows remain in native menus/shortcuts. No website restyling or additional app sidebar.

Reuse SnapshotModels, SnapshotStore, SnapshotLibrary and recovery text unchanged. Isolated integration uses its own bundle identifier, profile, defaults and SQLite directory. Production SQLite format remains compatible; no existing database is opened for writing or copied automatically. WK login cannot be transferred; normal CEF login is required.

2026-10-20 appearance amendment: the requested night mode replaces the fixed-light
native chrome requirement above. 页面 > 外观 offers persisted system (default), light
and dark choices for all native windows and recovery panels. Light keeps #F9F9F9
with #313131 controls; dark uses #1C1C1C with #EEEEEE controls. The refresh glyph
must remain readable while the window is active or inactive. Preserve the 40 pt
header, window controls and conversation; changing appearance must not navigate
or restyle the official website, which retains its own theme setting.

2026-10-20 simplified CLINX amendment (supersedes the earlier automatic binding
and inbox contracts): 收取 sends one fixed ordinary query in the current loaded
conversation. ChatGPT owns task identity, CLINX status lookup and result analysis.
Remove automatic identification, pairing/binding UI and stores, Observer access,
polling and automatic result delivery from OP. Preserve existing files/Keychain
entries without reading or writing them. Keep night mode and all unrelated
browser/protection behavior. Do not send over drafts, attachments or visible
modals. Explicit queries are allowed during generation using the webpage’s
available send/queue control; do not click Stop or infer a generation lock from
streaming markers. Disable concurrent clicks, verify a newly submitted
user bubble, permit a later explicit repeat, and never auto-retry uncertain sends.
Acceptance requires real CEF composer/native-button tests, draft/streaming-send/attachment/
modal/navigation/no-readback guards, existing appearance/protection/restart
regression, strict signing, and a backed-up Air installation matching the candidate.
Real-site/UI evidence is recorded separately from synthetic checks.

2026-10-20 header refinement: show only the tray and refresh symbols, without
收取 text. Both controls use borderless native buttons with a rounded hover surface,
visible while the pointer is inside, plus a stronger pressed state. Keep equal 32 x 28 pt hit targets with
an 8 pt gap. Both icon tints use exactly the title color, including muted inactive
light/dark states. Preserve tooltips, accessibility labels, actions and the 40 pt
header. A small NSButton subclass tracks entry/exit and paints only the rounded background;
AppKit retains click, pressed-state tracking, disabled handling and accessibility.

2026-10-20 Figma amendment supersedes the previous header styling and the
uninstalled inset/color experiment. The source is the owner's completed
“02 你的调整区” in Figma file `xWHKogXYl3WijpAvXxn7MP`, page
“顶部栏 · 当前基线与调整”. Use the exported vectors without replacing them
with similar symbols. Bundle Inter Bold at 13 pt, including its OFL license.

- Night: #1C1C1C background, active title/icons #A1A1AA, inactive title #6E6E6E.
  The inactive design contains no right-hand icons; hide both in that state.
- Night hover: #2E2E2E, 32 x 30 pt, radius 4 pt, top 5.002 pt, right 12 pt,
  gap 4 pt. Each button shows its own background while hovered/pressed.
- Night collect uses the exact square/checkmark vectors; refresh uses the
  exported refresh path. Centers are 64 and 28 pt from the right edge.
- Night native traffic-light centers: x 18.5/41.5/64.5 pt, y 19.5 pt from top.
  Title starts at x 95 pt with baseline 24.727 pt from top.
- Light active remains as drawn: #F9F9F9 / #313131, original tray vector,
  centers 64/24 pt from right, y 18 pt; title x 90 pt, baseline 21.727 pt;
  traffic-light centers x 16/39/62 pt, y 16 pt. Unspecified light inactive
  behavior retains the existing #707070 tint; no new style is inferred.

Keep native target/action, tooltip/accessibility names, 40 pt header, dynamic
conversation titles and system-managed full-screen controls. Query, refresh,
night mode and snapshot protection behavior remain unchanged. Final verification
must include real native pointer hover evidence and current isolated CEF tests,
then a backed-up, hash-verified installation on Air. The export and delivery
receipt are retained locally under `build/Figma-Delivery-20261020`.

2026-10-20 background completion notification amendment: after observing a
live assistant turn move from in_progress to complete and settle for 1.5 seconds,
request one macOS local notification only when OP is inactive. Historical
completed turns, reloads, foreground completion, errors, user Stop and duplicate
DOM observations are silent. A later regeneration may notify once again.

A separate metadata-only observer in the existing trusted main-frame isolated
world emits only document/conversation identity and a sequence number. It must
work when snapshots are paused or message capture identity is unavailable,
without weakening snapshot validation or starting CLINX work. No server, APNs
account, network polling or reply body is involved. Page completion remains
separate from server-side completeness. Closed/unloaded pages, sleep and OS
notification/Focus policy remain delivery boundaries.

Use UserNotifications authorization for alert/sound. 页面 > 后台回复完成提醒
persists the on/off choice. Notifications use generic text and clicking one
returns to its conversation. Validate actual CEF transitions and native policy
through an isolated delivery sink; record authorization/banner interaction
separately from those tests. Preserve the owner-approved header unchanged.

## Milestones and gates

1. Establish build target/runtime: pinned CEF 154.0.34+g14c5a08+chromium-154.0.8037.98; AppKit+SwiftUI host; same-identity nested signing; bounded shutdown before CefShutdown. Verify Release/signature/startup before adding real-login acceptance.
2. Restricted observation: internal public CEF DevTools API (no remote debugging listener), named isolated world, main frame and exact origin checks, bounded snapshot-only bridge, SQLite acknowledgement, sequence/conversation validation. No filesystem/network/native command API exposed to pages. Failure closed with visible protection status. Page completion is not server finality.
3. Per-window 3-entry LRU, one retained NSView per session, official browser visibility on cold selection and load/error states, memory-pressure trimming, explicit local restore. Startup and normal navigation never display a local transcript overlay. Local replies are shown only in the user-invoked recovery sheet. Clear/pause must disable capture in all contexts; renderer failure retains native shell/local copies and offers retry, no reload loop.
4. Regression and UI: synthetic CEF bridge/security, dedup/error/stream/restart tests; reuse prior WebKit tests proportionally; native toolbar, multiwindow and clean exit; real login/website verification only in the isolated integration app. No repeating user-verified prototype scrolling as a new demo. Performance metrics must separate native selection, real visible/sync timing and process aggregate RSS; missing real frame metrics stay unverified.

## Boundaries and acceptance

No change to current OP or prototype runtime, no /Applications replacement. Existing user work remains active. No credentials/cookies/tokens/headers in evidence. Synthetic content only for automated tests. Retain 403/429/error snapshot protection and completion states. Release build and synthetic tests alone do not establish production readiness. Final report distinguishes PASS, BLOCKED, NOT_RUN and user-observed prototype improvement from controlled product measurements. Developer ID/notarization remains separate from local Apple Development signing.

## Official webpage only during normal use — 2026-10-20

Delete the automatic local transcript overlay, its selection/loading state and
its snapshot-read/handoff task. Opening, switching, reloading and failed loading
keep the CEF browser visible. Keep snapshot capture/storage and the explicit
File > 本地回复副本… sheet. Choosing an official conversation dismisses that sheet.
Preserve the approved header, manual CLINX query and background reply reminders.

Validate startup, cold switches with/without snapshots, HTTP errors, explicit
recovery and return to the official browser. Install the verified Air artifact
with rollback and production-data preservation. Close review processes and
fixture services, unregister temporary app copies, and remove OP review, CEF
Alerts and prototype notification settings through the system reset action;
preserve the installed OP entry and other applications' settings.

Do not package the optional CEF Alerts helper: its automatic macOS registration
recreates a separate unwanted notification entry. Keep native OP notifications
and the generic/GPU/renderer browser helpers. Remove stale Alerts output before
signing incremental builds.

## Light header follows approved night layout — 2026-10-20

Apply the existing night geometry, traffic-light positions, title baseline/font,
collect/refresh glyphs and focus behavior to light mode. Keep the existing light
background and active foreground palette. In both appearances, inactive windows
show a muted #6E6E6E title and hide right icons; hover surfaces retain 4 pt corners.
Do not change approved night geometry or website content/styles.

The owner subsequently authorized completing validation directly on Air because
iMac remains locked. Inspect light/night focused, unfocused and hover header
renders on Air before installing, then verify the installed window. Finish by
closing isolated processes/listeners and unregistering review app copies.
Preserve production data, notification preferences and a rollback app bundle.

## Query submission readback — 2026-10-20

Confirm a newly observed matching user-message identity after an explicit send;
do not require the total number of identical queries to increase. History may
be unmounted while the new turn arrives. Retain existing search-unit keys across
DOM remounts so re-rendered history alone cannot confirm a send. When a user
wrapper uses `display: contents`, inspect its rendered contents rather than
requiring the wrapper to have a layout box. Truly hidden messages still cannot
confirm submission. A matching node without a stable supported message key
cannot confirm submission; DOM object identity alone is insufficient after a remount.
Preserve draft/busy/modal/attachment/navigation guards,
read-only consultation preflight, and the rule against automatic retries.
