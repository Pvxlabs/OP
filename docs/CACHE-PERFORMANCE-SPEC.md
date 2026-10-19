# OP cache and switching performance contract

2026-10-19. Preserve all pre-existing uncommitted branding/migration changes.
Linear remains waived by the user in this thread. No change to bundle ID, website
store, snapshot data format, upstream DOM styling or authentication.

## Scope and milestones

1. Instrument existing behavior without optimizing it. Establish repeatable
   real ChatGPT A/B/C switching, return-to-old, restart and two-window evidence.
   Synthetic tests remain a separate correctness tool, never a real-site baseline.
2. Correct measured unnecessary view attachment/navigation work and cold recovery.
   Keep max three views/window, no speculative network preloading, pressure trim.
3. Focused regression for identity isolation, pending selection dedup, LRU,
   reconstruction, cold handoff, failure protection and pressure. Release build,
   actual native UI and equivalent real-site before/after measurement.

## Measurement contract

Separate native selection, native WebView attachment, locally rendered recovery,
validated official body observation, explicit navigation count and app RSS.
A public WebKit render snapshot can establish an upper-bound time when official
text is present in a rendered bitmap. It does not measure physical display scanout.
View mount or rAF callbacks alone never establish first visible ChatGPT content.
Record unobservable metrics as unavailable, never substitute fixture timings.
WebKit helper RSS attribution may be unavailable; app RSS is not total WebKit RAM.
Logs contain only ephemeral operation IDs, durations/counts/states and statuses;
no private body, conversation IDs, credentials, cookie/token/auth headers.
Use existing synthetic conversations and any newly created clearly synthetic
chats only. Do not operate work conversations or ChatGPT Classic.

## Correctness contract

Cold selection clears prior presentation, uses a request identity for async reads,
and displays only the target conversation's native local text. It never injects
snapshots into the webpage. Keep local presentation until validated official
identity and a usable message body are observed, with an explicit option to see
website login/verification/failure. Page-ended does not certify server completion.
403/429, error/empty and interrupted observations retain existing snapshot guards.
A switch may not reuse a view simultaneously across windows. Capacity limits are
counts/record budgets, not a promise of a fixed WebKit RSS ceiling. Pressure drops
inactive views; active work remains. Old request results cannot cover a newer chat.

## Acceptance

Publish real before/after raw metadata, sample size, measurement meaning and
limitations; no absolute-zero or fully-native claim. Explain remaining failures,
rate limits or missing display/process evidence. No reset/clean, no unrelated
refactoring, no install/replacement or Git commit unless subsequently authorized.

## Milestone results (2026-10-19)

- M1: real-site exploratory A/B/C baseline captured before optimization. A SPA
  route/label alias invalidated the first run; distinct IDs fixed it. Seed B/C age
  expired in later exploratory runs, so cold local-body timings are invalid.
- M2: stable WebView deck, target-gated native cold/restart preview, pending-view
  reuse, bounded telemetry and inactive-view pressure trim implemented. No store
  schema, bundle identity, authentication or website style changes.
- M3: 58 focused checks PASS; production and isolated Xcode Release builds PASS.
  Isolated actual UI confirms long native startup preview survives website read
  failure. Current-source cold B preview observed; official B handoff blocked.
  Final rebuilt candidate showed native A then matching official A (handoff PASS);
  same-target handoff also covered by real WebKit fixtures. Final fresh-seed controlled real-site pair BLOCKED at official
  startup body (HTTP 200 document but zero identified reply nodes). No further
  repeated website experiment. Physical display latency and total WebKit RSS
  remain unmeasured. See acceptance report for evidence and scope limitations.
