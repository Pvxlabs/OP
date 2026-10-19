# OP CEF isolated product integration

Status: after isolated validation, the user explicitly requested direct replacement. CEF is now installed as /Applications/OP.app using the existing CEFIntegration data identity, with the WK app/data retained for rollback. First-turn DOM identity coverage and remaining product-acceptance gaps are still unresolved; installation does not establish those checks as passed. See CEF-INTEGRATION-ACCEPTANCE.md.

## Contract

Create an Apple Silicon Release target in Integration/CEF using the already pinned CEF distribution. Keep all existing WebKit source, Xcode target, dirty work and installed bundles intact. Skip Linear as explicitly directed earlier in this thread. No commit, push or data migration/cookie export.

Native AppKit owns NSApplication and CEF's main loop; SwiftUI owns per-window state, local recovery and panels. A narrow C ABI hosts windowed CEF NSViews. Native unified toolbar follows the supplied Codex reference and subsequent refinement: system traffic lights and title only, with a 40 pt title area. Only a native refresh icon at top right; no other custom titlebar buttons, title capsule or shadow. Native titlebar accessory displays plain text; titlebar background is #F9F9F9. Back/forward, recent local copies, protection and new windows remain in native menus/shortcuts. No website restyling or additional app sidebar.

Reuse SnapshotModels, SnapshotStore, SnapshotLibrary and recovery text unchanged. Isolated integration uses its own bundle identifier, profile, defaults and SQLite directory. Production SQLite format remains compatible; no existing database is opened for writing or copied automatically. WK login cannot be transferred; normal CEF login is required.

## Milestones and gates

1. Establish build target/runtime: pinned CEF 154.0.34+g14c5a08+chromium-154.0.8037.98; AppKit+SwiftUI host; same-identity nested signing; bounded shutdown before CefShutdown. Verify Release/signature/startup before adding real-login acceptance.
2. Restricted observation: internal public CEF DevTools API (no remote debugging listener), named isolated world, main frame and exact origin checks, bounded snapshot-only bridge, SQLite acknowledgement, sequence/conversation validation. No filesystem/network/native command API exposed to pages. Failure closed with visible protection status. Page completion is not server finality.
3. Per-window 3-entry LRU, one retained NSView per session, matching local snapshot on cold selection and identity-checked handoff, memory-pressure trimming, explicit local restore. Startup navigates the official website before querying recent snapshots and never displays a local transcript overlay. Clear/pause must disable capture in all contexts; renderer failure retains native shell/local copies and offers retry, no reload loop.
4. Regression and UI: synthetic CEF bridge/security, dedup/error/stream/restart tests; reuse prior WebKit tests proportionally; native toolbar, multiwindow and clean exit; real login/website verification only in the isolated integration app. No repeating user-verified prototype scrolling as a new demo. Performance metrics must separate native selection, real visible/sync timing and process aggregate RSS; missing real frame metrics stay unverified.

## Boundaries and acceptance

No change to current OP or prototype runtime, no /Applications replacement. Existing user work remains active. No credentials/cookies/tokens/headers in evidence. Synthetic content only for automated tests. Retain 403/429/error snapshot protection and completion states. Release build and synthetic tests alone do not establish production readiness. Final report distinguishes PASS, BLOCKED, NOT_RUN and user-observed prototype improvement from controlled product measurements. Developer ID/notarization remains separate from local Apple Development signing.
