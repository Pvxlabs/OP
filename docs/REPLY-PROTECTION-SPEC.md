# Local reply protection and recovery — implementation contract

2026-10-19. Extends the accepted 0.1.0 baseline. Linear remains waived by the user.

## Objective and boundaries

Protect text already delivered to the rendered page, preserve default persistent
WebKit website data, and restore recent local conversations without unnecessary
loads. This is defensive storage, not a claimed fix for the unconfirmed upstream
reply-disappearance cause. No private endpoints, network interception, credentials,
cookie access, DOM styling changes, or modifications to other installed apps.

## Milestones

1. Verify real synthetic-chat DOM identity/body/status signals. Specify a
   conservative observer and test its actual WebKit bridge using synthetic HTML.
   Unknown identities are skipped; unknown completion remains unverified.
2. SQLite transactions and merge policy. Preserve protected complete text and
   nonempty partial text across empty/error observations, interruption and restart.
   Reconciliation uses conversation + message identity, never body alone.
3. Native recovery view, recent-conversation navigation, bounded live WebView
   reuse, cleanup and local-only diagnostics. Keep website data independent.
4. Synthetic regression, real website observation, Xcode build and native UI
   acceptance. Record measured loads/switches and every unverified boundary.

## Storage and state contract

- Per-message identity, role, body, SHA-256, observation state and timestamps.
- Confirmed completeness is never inferred from DOM alone. Verified turn-local
  `complete` plus 1.5 seconds of stable nonempty body establishes only pageEnded
  (completeness unverified), separate from complete. Spinner/time/global live
  region never establishes either. The current observer has no production path
  that emits confirmed complete. Observed Stop remains interrupted across reads.
- Unknown state, streaming, interruption, read failure and conflict remain distinct.
- Empty/error/loading observations never replace useful saved text. Different
  complete text for the same ID preserves the prior complete copy and exposes a
  conflict rather than silently replacing it.
- SQLite is separate from WKWebsiteDataStore and namespaced by bundle ID. No
  text/IDs in operational logs. Only synthetic-test metadata records IDs/hashes.
- Bounded retention: 200 conversations, 30 days, 64 MiB logical records, max 500
  messages per conversation, 1 MiB per message. Cleanup removes oldest whole
  conversations for age/byte/conversation limits, oldest messages for the per-chat
  message limit; UI explains that local history may be partial and offers clearing.
- Live WebViews: at most 3 per window. Reuse is within that window; never share
  one NSView between simultaneous windows. Evicted sessions stop loading and
  detach handlers. Cold selection loads once; warm selection loads zero times.

## Acceptance and dependencies

Synthetic WebKit + SQLite integration must cover complete save/reload, empty and
error protection (including simulated 429 read failure), stream interruption,
identity-safe dedup/reconciliation, cleanup, clearing, process restart, malformed
payload rejection, bridge origin/frame restrictions, and view reuse/load counts.
Real website evidence must separately verify DOM compatibility and native login
behavior; synthetic evidence cannot establish those. Challenge/login handoff may
be required. No server completion claim without an observable reliable signal.

## Initial review

Baseline already keeps a BrowserSession in SwiftUI @State and does not reload in
updateNSView or activation. It has no message cache/recovery or recent view pool.
Previous RCA verified data-dil-message-id on synthetic replies; the global
"回答已完成" live region is not a per-message completion signal. Chrome was blocked
by Cloudflare. Normal user login in an isolated WebKit test profile enabled real
inspection: data-dil-message-id matches selection message/conversation IDs inside
an explicit :assistant search unit. No .markdown or author-role attribute exists
on those current reply nodes. User bubbles expose no verified stable ID; skip them.
During actual streaming the secondary selection-message ID is absent, while the
primary ID, selection conversation and assistant search references remain stable.
Capture those partials; validate the secondary ID when present, not before it exists.

## Progress

- Planning/source review: complete.
- Real identity/role/body gate: verified in synthetic conversation
  6ad53b9b-28fc-83ee-bc67-e0dedda504c4. Real turn transition in_progress -> complete
  observed with body growth 0 -> 2477 DOM characters. This proves page state only.
- Implementation: SQLite merge, delta observer, native recovery, bounded view pool.
- Validation: see PROTECTION-ACCEPTANCE.md for exact evidence and remaining gates.
