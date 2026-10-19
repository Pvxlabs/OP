# CLINX automatic task identification in ordinary ChatGPT

> Historical contract, superseded on 2026-10-20 by the simplified manual query
> action in [CEF-INTEGRATION-SPEC.md](CEF-INTEGRATION-SPEC.md). Automatic
> identification, pairing/binding, Observer polling and the task inbox are removed.


Date: 2026-10-20 Asia/Shanghai. Status: IMPLEMENTATION PASS / FIXTURE PASS / BOUNDED REAL-CHAT ACCEPTANCE PASS.

## Objective and boundaries

Zero user pairing and no per-task ID entry. Keep ordinary original ChatGPT chats.
OP asks the ChatGPT agent in the source conversation to identify the actual CLINX
execution it created using its own tool context, corroborates exact identities
through the existing read-only Observer, then uses the durable result inbox.
The native top bar contains a frequent 收取 action beside refresh.

The user explicitly rejected per-conversation pairing. No CLINX service, storage,
protocol, execution authority or deployment changes are required by this design.
No title/time-based source matching, private ChatGPT endpoint, network interception,
cookie extraction or Work conversion. Preserve existing dirty work and inbox files.

## Verified evidence and trust model

The current Observer has task/execution/result identities but no ChatGPT source
UUID. A bounded real ordinary-chat capability test displayed a tool activity
summary without raw creation identities in the inspected DOM. It returned NOT_FOUND
/ Tunnel-client has not been seen for 300 seconds and created no tasks. This does
not prove every website variant hides all tool results.

OpenAI documents anonymous _meta["openai/session"] correlation, but not equivalence
to the /c/ URL UUID. A proposed CLINX extension and one-time pairing was rejected
by the user. Official reference: https://developers.openai.com/plugins/reference.
MCP Events are documented for Work/cloud/dots and are not used for this request:
https://developers.openai.com/plugins/build/mcp-events.

ChatGPT's source selection is AI identification from its existing conversation
context. Observer readback independently proves the task/execution pair, NOT the
ChatGPT provenance. Never describe that source inference as a server-certified
creation record. Invalid, ambiguous, missing or mismatched selections do not bind.

## Implementation contract

1. Inspect only identity-verified ordinary source conversations and complete
   assistant turns. New CLINX/Codex-related turns are candidates, not bindings.
   Quoted IDs, titles and activity labels never bind tasks directly.
2. Issue at most one visibly marked, durable automatic identity request for each
   source assistant message. Ask ChatGPT to use only the actual CLINX creation/
   start result from that turn, exclude pasted/example/status/prepare-only data,
   call no tools and execute nothing, and return a bounded nonce-tagged JSON list.
   After the initial history baseline, newly observed sources are processed in
   order. Persist the selected source ID and its query in the same atomic ledger
   write so multiple sources in one poll are not silently marked handled.
   Uncertain identification must return an empty list. No user pairing step.
3. Preserve drafts, attachments, busy/modals, exact chat identity and all existing
   composer guards. Persist before sending. Crash/uncertain writes only read back;
   never automatically repeat a query. Exclude OP identity/result responses from
   candidates so the feature cannot create a self-triggering message loop.
4. Accept only the immediate completed assistant response to the exact query user
   bubble, matching nonce and canonical source UUID, <=10 schema-valid selections
   affirming created_here. Independently GET exact task details, require matching
   execution_ref, reject other-chat existing bindings, then persist automatic
   inbox bindings. Failed Observer verification remains read-only retryable.
5. Automatic mode skips terminal results older than the persisted activation time;
   time is solely a historical replay filter, never source matching. Explicit
   收取 may inspect a previously observed source and allow its historical result
   without another AI message. Active executions and new results are collected.
6. Poll while OP runs. Existing result receipt gates, frozen messages, unique
   execution bindings, uncertain no-resend, original-chat submission and separate
   assistant response readback continue unchanged. Configurable global automatic
   identification toggle is enabled for the user's requested zero-setup flow.

## Milestones and acceptance

- A1 top-bar action: PASS. 收取 sits beside refresh in the 40-point native header;
  night contrast, button opening/refreshing the inbox and collapsed manual fields
  were verified in the real UI. Installed at /Applications/OP.app.
- A2 automatic AI identification: PASS. Owner-only durable query ledger, no user
  pairing and no per-task ID entry. Existing inbox format remains compatible.
- A3 validation/delivery: PASS within the stated scope. Real CEF fixtures cover
  automatic query -> schema/readback -> Observer -> automatic binding -> result
  receipt -> assistant response, plus mismatch, quote/empty, nonce, history and
  restart/no-repeat cases. Real ordinary ChatGPT also completed that chain using
  an existing historical execution and explicit top-bar collection. No new CLINX
  execution was created for testing, and no CLINX code/service was modified.

## Evidence

`build/CEFIntegration/evidence/run-20261020-031706`: 81 core + 4 restart PASS.
The happy path makes no manual bind call. Identity queries in the fixture now
include a visually collapsed user body and Show more/less controls. Readback
strips controls and compares the complete DOM text to the immutable payload;
nonce/source UUID and immediate-assistant-response checks remain strict. Two
new source turns observed in the same poll are each identified once, with one
unique binding when both identify the same execution. Seen-source and new-query
records are persisted in one atomic ledger write.

Real ordinary test chat: one automatic identity request received a matching JSON
empty list after a capability-only turn. No execution was bound. It survived
relaunch without another query. Keychain authorization initially blocked Chromium;
the user handled it. No SecurityAgent UI interaction or Keychain policy change
was performed. The earlier MCP tunnel failure was a dated observation; a fresh
read-only get_capabilities later succeeded.

Real original work chat: 策略插件化架构升级 identified the existing task
ORION P1.6 — DATA Qualification & Release Readiness. Observer exact-task readback
verified its execution identity. Because its terminal result predated activation,
automatic mode skipped historical replay. Clicking top-bar 收取 reused the same
AI identification, bound it without ID entry, delivered its actual Observer
summary to that same ordinary chat, and observed ChatGPT's response. ChatGPT
explicitly distinguished execution termination from business qualification;
this acceptance does not certify that ORION task's business outcome.

Local screenshots: build/clinx-auto/live-identification-empty.png,
live-inbox-connected.png, live-original-identification.png and
live-original-response.png. Owner-only live ledger and inbox preserve the exact
query/receipt state; build/clinx-auto/live-acceptance.json records bounded states
and counts without credentials or full result content.

The expanded run run-20261020-031334 exceeded the test harness's 120-second
limit; that harness terminated the fixture before the sixth source chat loaded
and produced a load failure. The harness limit was adjusted to 180 seconds for
the larger suite, without changing product assertions. The final complete core
and restart phases above passed.

Release builds and strict deep local signatures passed. Installed executable,
native library and delivery adapter match build/clinx-auto/final-candidate-hashes.json.
The previous installed version is recoverable at
build/clinx-auto/OP-replaced-manual-20261020.app; an additional original backup is
build/clinx-auto/OP-before-auto.app. The intermediate real-acceptance 83-check build
is also retained at build/clinx-auto/OP-auto-83-20261020.app. Its delivery adapter
is identical to the final installed adapter; the subsequent change only fixes
multiple-source scheduling and atomic seen/query persistence, covered by the final
85 checks. The original night preference and login/data
identity are retained.

## Operational limits

Identification scans eligible completed assistant turns in open, readable,
identity-verified ordinary chats while OP runs. It uses CLINX/Codex/ref-related
visible turn signals to choose source candidates; it does not intercept every
hidden tool event or scan every closed conversation. Missing source identity,
ambiguous AI selection, mismatch or inaccessible Observer never creates a binding.
Closed/unreadable source conversations wait before receipt delivery. The existing
fresh-first-turn DOM identity gap and distribution/benchmark gaps remain outside
this milestone; no universal provenance or unattended closed-chat claim is made.

During startup diagnosis the candidate moved to CEF's normal initial URL and the
isolated observer's existing runImmediately backfill, avoiding a second competing
navigation. Full CEF capture/lifecycle/restart checks and the real login-profile
launch passed. This remains bounded startup evidence, not a long-duration claim.
