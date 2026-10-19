# CLINX results in the original ordinary ChatGPT conversation

Date: 2026-10-20 (Asia/Shanghai). Implementation contract.

## Objective and scope

OP receives the authoritative result of an explicitly bound CLINX execution and
sends a visible follow-up user message in its original ordinary chatgpt.com
conversation. Observe the matching user bubble and a subsequent assistant response;
neither a native notification nor a successful click proves this path succeeded.
Use the existing CEF app, native menus and a native CLINX inbox window. Preserve
the current website layout, night mode, login profile and reply protection.

## Existing contracts and dependencies

- Existing private HTTPS Observer: GET /v1/health, /v1/tasks?state=recent&offset=0,
  and /v1/tasks/{task_ref}; schema_version 1, Bearer read-only credential. No new
  CLINX server endpoint or mutation. Verified live health/list on this machine.
- v1 details describe the current execution only. Require exact task_ref,
  execution_ref and final_result.execution_ref. Refuse successor/history mismatch.
- final_result is a bounded redacted summary, not the full Codex report. Preserve
  summary, validation, blockers, next_state, truncation and redaction labels.
- CLINX Monitor connection can be explicitly selected in OP. Read its configured
  endpoint/account and Keychain credential without exporting/logging credentials.
  Manual configuration stores the token in OP's Keychain, never defaults/JSON.
- CEF isolated main-frame DOM access on exact official origin. No private ChatGPT
  endpoint, cookies/token extraction, network interception, or API conversation.

## User flow

1. Open 页面 > CLINX 任务收件箱. Configure/test Observer (or choose the existing
   Monitor connection). Bind task_ref + execution_ref to the current /c/ UUID;
   opt in to automatic sending for that binding. No binding inferred from titles.
2. Poll every 15 seconds while OP is running. Only terminal exact execution with
   codex_running false and an exact persisted final_result becomes ready. Unknown,
   stale, running and missing results remain visible waiting/error states.
3. Persist receipt and unique execution binding before browser writes. Send only
   in an open, selected, identity-verified original conversation. Closed/cold chats
   wait; a native action opens the original conversation for delivery.
4. Refuse writes while there is a draft, attachment, modal, generating response,
   wrong identity, local overlay, unsupported composer or failed login/readback.
   A follow-up is visibly labeled CLINX result summary and includes its unique
   receipt marker. It requests evaluation of the original objective without
   granting follow-on execution authority. Result text is delimited as data.
5. Read back a matching user bubble; separately observe a following assistant
   response. These mean visible submission/response only, never server persistence
   or completed generation. Do not automatically resend after a click, crash or
   timeout with uncertain outcome. Read-only verification can recover certainty.

## Persistence and boundaries

One app-wide JSON inbox in the existing bundle's Application Support directory,
owner-only permissions, atomic writes and bounded entries. Failure to save blocks
all sends. One receipt per execution, even across windows/restarts. An interrupted
send becomes uncertain on restart. Pause is available; no automatic replay of
uncertain sends. Account/conversation access must be freshly observed before send.
Credentials never enter inbox, website payloads, screenshots or diagnostics.

OP must be running/logged in for sending; resume polling on launch. No daemon,
email integration, Work/Cloud migration, automatic task creation, CLINX service
changes, or unrestricted Codex continuation. No commit/push unless requested.

## Milestones and acceptance

- M1 contract/scope: PASS. Global AGENTS Linear requirement removed by request;
  Observer health/read-only task list verified; current-execution limitation noted.
- M2 native binding, Observer client, durable inbox: PASS for fixture contracts,
  exact identity, terminal/result gates, duplicate bindings, pause/resume,
  persistence failure and crash recovery. Native application Keychain access, live
  Observer health and the recent 50-task list also passed after user authorization.
- M3 constrained CEF follow-up/readback: PASS on real CEF synthetic fixtures for
  draft/busy/wrong-chat/modal/attachment guards, unique sends, reload/restart,
  missing user-bubble uncertainty, read-only verification and assistant readback.
  Real-site selectors are separately verified by M4.
- M4 delivery: PASS for this bounded implementation. Release build and local
  strict signing passed. Native Monitor credential/Observer health/recent task
  access passed. The real ordinary ChatGPT test chat received one synthetic
  receipt through the production adapter and replied OP_CLINX_DELIVERY_ACK in
  that same chat. The validated app is installed with recoverable old bundles.
  No real task report was forwarded to an unrelated test conversation.

Record implementation and evidence here as each milestone actually passes.

## Acceptance evidence

`build/CEFIntegration/evidence/run-20261020-022257`: 66 core + 4 restart checks
PASS, including the complete fixture Observer HTTP -> durable inbox -> original
CEF conversation -> user receipt -> subsequent assistant response pipeline.
The fixture now matches the observed current website: no fixed editor ID,
a form submit button without the old test ID, and message-unit user identity.

`build/clinx-delivery/live-site-final/site-check.json`: responding. The explicit
independent ordinary ChatGPT test conversation received one labeled synthetic
receipt through the production adapter and produced OP_CLINX_DELIVERY_ACK.
`live-chat-response.png` records both bubbles in that same real conversation.
This is a real website adapter check using synthetic data, separate from the
complete fixture pipeline. No unrelated real task report was sent for testing.

`build/clinx-delivery/live-observer.png`: the native application used the existing
Monitor credential and successfully read 50 recent tasks from the real private
HTTPS Observer. Credentials were not printed, exported, or put in screenshots.

`build/clinx-delivery/installed-hashes.json`: installed main executable, native
library and delivery script match the validated candidate. Strict deep signature
verification passed. The old night-mode bundle is retained at
`build/clinx-delivery/OP-before-clinx.app`; profiles/defaults were not migrated.
The original conversation was restored after installation. A final native shortcut
correction makes Cmd-W close the key window; manual acceptance confirmed the
inbox closes while the original chat stays open. The website adapter hash is
unchanged from the successful live test. Native Observer access and the 70 checks
were reverified on the final build. Changes are uncommitted.

## Diagnosis retained

Initial startup failures also reproduced with an isolated copy of the installed
baseline and a fresh review profile. Native HTTP reached the same loopback server
while CEF sent no request. A normal candidate process sample showed Chromium's
worker blocked in SecItemCopyMatching / Keychain decryption, and the Monitor
credential reader blocked in the same system call. The user handled the macOS
Keychain authorization themselves; Computer Use did not operate SecurityAgent.
Production uses the system Keychain and existing profile without a fallback.
No global Keychain access policy, proxy, credential or CLINX service was changed.
Synthetic tests use --use-mock-keychain only with an isolated application identity.

The first real-site attempt stopped before writing because the editor had no
fixed prompt-textarea ID. A second attempt left only a synthetic draft when the
old send-button test ID was absent; its uncertain state did not auto-retry.
Metadata diagnosis confirmed one visible contenteditable in the form, the native
HTML submit button, and :user / :assistant message-unit suffixes. The adapter and
fixtures were corrected to those actual contracts. The unsent synthetic test draft
was explicitly cleared before the final successful acceptance; the failed attempt
metadata remains in build/clinx-delivery/live-site and live-site-fixed.

For future explicit live acceptance, close OP first (exclusive profile ownership),
then use --clinx-site-check=<independent-test-conversation-UUID> with
--evidence=<absolute-directory>. It sends one synthetic receipt, performs only
readback afterward, and records bounded metadata. A waiting or uncertain result
never triggers another write. Never point acceptance at a real work conversation.

The isolated review Chromium profile used before diagnosis remains at
`~/Library/Application Support/local.personal.OP.CEFNightReview/Chromium-before-clinx-check`.

## Automatic association and top-bar collection — 2026-10-20 extension

The user requested zero manual pairing and no per-task ID entry, plus a native
收取 button beside refresh. The user rejected a one-time pairing proposal.
Implementation now follows [the automatic identification contract](CLINX-AUTO-BINDING-SPEC.md):
ChatGPT identifies its actual source tool context, the read-only Observer verifies
exact task/execution identity, and OP creates durable inbox bindings automatically.
This extension is completed with bounded real-chat acceptance and is not covered by the prior 70-check acceptance.
