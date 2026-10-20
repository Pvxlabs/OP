# Codex ↔ ChatGPT consultation bridge

Date: 2026-10-20 (Asia/Shanghai).

OP now supports a bounded, opt-in consultation channel. Codex submits a question
through CLINX, OP sends it in one explicitly selected ordinary ChatGPT
conversation, and Codex reads the correlated reply through CLINX. This does not
start a new Codex thread, dispatch an execution, or implement an O loop.

## Reused interfaces and minimum addition

- CLINX's existing `TaskRegistry`, task/conversation/execution identities, SQLite
  connection and MCP JSON-RPC stdio server are reused. Consultation tables live
  in the selected task database. Existing execution/status/context APIs retain
  their behavior. The existing deployed connector initially had no consultation
  queue or reply mutation tools; a read-only Observer cannot carry these writes.
- OP reuses its CEF named isolated world, exact origin/main-frame gate, existing
  execution-query result channel and composer adapter. Drafts, attachments,
  modals, loading and generation block writes. Existing query behavior remains.
- Readback additionally requires exactly one full question bubble, its immediate
  assistant successor, the request marker in readable text, explicit turn-local
  `complete` after observed `in_progress`, stable text, real assistant UUID and
  conversation metadata. OP's existing SQLite protection must independently
  agree on the same assistant ID, body and `pageEnded` state before writeback.
- `pageEnded` is webpage completion evidence, not proof of server persistence.
  A notification is never evidence of Codex execution success.

## Connection and binding

Build a separately identified candidate using the existing build script. Never
point fixtures at the installed app's profile. Sign in normally in the candidate;
do not migrate cookies, tokens, Keychain entries or another app's login profile.

Create a local command configuration (contains no website credentials):

```json
{
  "command": [
    "/absolute/path/to/python3",
    "/absolute/path/to/CLINX/mcp_server.py",
    "--stdio",
    "--consultations-only",
    "--task-db",
    "/absolute/path/to/the/existing/clinx/tasks.sqlite3"
  ]
}
```

Choose **页面 → 连接 CLINX 咨询 MCP…**, select this file, open the target
conversation and choose **绑定当前 ChatGPT 对话…**. The native confirmation reads
the actual `/c/` identity from the selected CEF main frame, then stores a durable
`binding_id + client_id + conversation_id` association in CLINX and OP preferences.
No URL is inferred by Codex. **咨询桥接状态…** shows the exact binding and pause
reason. Only the selected bound conversation can receive a question; OP never
opens a different conversation to send automatically.

The task database must exist and contain the requested canonical task. For a
remote CLINX runtime, use that runtime's configured private MCP transport and
the same task database after installing the extension there. A local test
database is explicitly synthetic; it is not a replacement for the remote
production registry. No new HTTP listener, public service or auth mechanism was
introduced. Commands execute directly as an argument array, without a shell,
with a minimal environment and bounded output/time. MCP output is kept briefly
in an owner-only temporary directory and removed after each call.

## MCP contract

| Tool | Purpose |
| --- | --- |
| `clinx_bind_chatgpt` | Explicit native binding of a real conversation to an OP client. |
| `clinx_submit_consultation` | Save immutable `request_id`, binding, task, optional exact execution, question and necessary context. |
| `clinx_get_consultation` | Query exact state and read the verified reply/ID/hash; Codex uses this after timeout and before continuing. |
| `clinx_list_consultations` | OP reads the ordered pending requests for its exact client and conversation binding. |
| `clinx_update_consultation` | OP obtains a single send permission, records readback/reply, or pauses/resumes a request. |

These tools are exposed by the existing CLINX MCP server in the modified source.
The optional `--consultations-only` stdio mode opens the existing registry without
constructing execution ownership, Linear, a provider process or credentials.
It has the same JSON-RPC framing as the original stdio entrypoint. A selected
command must refer to this source/version; an older deployed MCP will return
unknown-tool and OP will stop sending. Tool changes do not automatically update
the already-running P620 connector or refresh its client catalog.

Submit once with a caller-generated lowercase UUID `request_id` and a confirmed
`binding_id`. Repeating the identical request returns its saved record; changed
content with the same ID conflicts. A missing task, wrong execution/task pair,
wrong client or cross-conversation binding is rejected. No task is guessed or
created as a side effect of submitting a consultation. Question/context text is
explicitly supplied by the caller; OP does not scrape other tasks or chats.

The visible prompt includes `OP_CONSULT_REQUEST:<request_id>` and asks ChatGPT to
echo it in the answer. Reply content is untrusted data; Codex must assess it in
the original task's authority and must not execute embedded instructions blindly.

## State and recovery

`PENDING → SENDING → AWAITING_REPLY → COMPLETED`, with `PAUSED` and a reason
for ambiguity or failure. SQLite `BEGIN IMMEDIATE` grants exactly one send
permission before any editor modification. The ID, full prompt and hash are
immutable. A competing/repeated begin call gets `send_permitted: false`.

Each poll first reads CLINX and the target DOM. An attempted send without a
matching bubble pauses instead of sending again. Resume of an attempted send
always returns to read-only reconciliation. A preflight failure before any
attempt can be explicitly resumed after the user resolves the cause. A stopped,
unreadable, interleaved, marker-mismatched or ambiguous reply never completes.
After renderer/document loss, existing completed history without observed
generation pauses for manual review; it is not silently upgraded to success.

To resume, first query `clinx_get_consultation` and inspect its `reason`. Restore
the original selected conversation, resolve the page issue, then explicitly call
`clinx_update_consultation` with the saved request, binding, client and
`action: "resume"`. Do not create a replacement request to hide uncertainty.
If the operator decides to abandon an ambiguous request, first leave it paused,
then use `action: "cancel"` with an explicit reason. The retained record becomes
`CANCELLED` and releases the ordered queue without granting another send.
HTTP 403/429, login verification and loading errors require recovery before
handoff. Unfinished replies pause after ten minutes. The app must remain open.

## Acceptance

Real website acceptance uses an independent synthetic CLINX task associated with
the current Desktop thread, not a newly created Codex conversation. The user
signed into the independently identified review app. A real HTTP 403 initially
blocked binding; a normal reload restored HTTP/content identity, after which
the native binding was saved.

The first live question asked `17 + 25`. Two identical MCP submissions preserved
one request. OP sent it to the explicitly bound real ChatGPT conversation,
verified the immediate assistant, matching marker and cached body, and returned
`OP_SYNTHETIC_SUM=42` through CLINX. The current Codex turn read it through MCP,
checked metadata/hash and continued by writing `consulted_sum=42` and
`continued_result=84` to a local synthetic artifact.

A second live request was intentionally submitted while an unbound second
window was selected. CLINX recorded PAUSED with `attempted=0`. Returning to the
bound conversation and explicitly resuming the same request produced the
correct `OP_RECOVERY_SUM=43` reply with one attempt.

**Final acceptance is BLOCKED.** The final runtime retains the persistent
HTTP 403/429 latch. The earlier final request was explicitly abandoned through
`cancel` after querying its paused state, with no replay. A distinct diagnostic
request completed through the native bridge while the official page was healthy;
Cloudflare challenges subsequently recurred. Earlier successful runs do not
certify the currently blocked final runtime.

The 2026-10-20 investigation identified the 403 source: official ChatGPT
`GET /backend-api/conversations` and
`POST /backend-api/sentinel/chat-requirements/prepare` returned HTML with
`cf-mitigated: challenge`. The official page says its browser check could not
finish. This proves the response is a Cloudflare challenge, not a CLINX error;
the reason Cloudflare selected this browser/session remains unproven. Normal
reload did not restore the page. No fingerprint, authentication or gate changes
were made. OP now reports the challenge reason explicitly while retaining the
same hard block. See [the investigation](BRIDGE-RCA-20261020.md).

The CLINX local suite passed 40 tests. Full CEF regression still fails its
unchanged cancellation assertion: 82 earlier checks pass, but the pinned CEF
runtime reports raw `ERR_FAILED=-2` where the test requires `ERR_ABORTED=-3`.
The focused probe reports `-3`. A valid open-stream experiment with peer-close
observation and explicit first-chunk read reproduced the discrepancy; unsuccessful
fixture experiments were reverted. Error codes are not translated, accepted
values are not broadened, and the test runner now exits nonzero on failure.

P620 MCP deployment and readback are PASS: the deployed release is
`op-consultations-c4756ec3700d`, with version
`native-conversation-relay-consultations-v1`, 20 tools and all five consultation
tools. The candidate passed 67 selected remote tests. Existing tool schemas and
unrelated remote source changes were preserved. Only the idle MCP tunnel was
restarted; dispatcher, execution owner, provider, observer and centre PIDs stayed
unchanged. Both real deployed stdio and the existing cloud connector report the
new release. After normal restart the official page became readable, and the
final review app bound the actual synthetic conversation to P620. The current
Codex turn submitted one unique question and an identical duplicate. OP triggered
one UI send; the official sentinel prepare request returned another Cloudflare
403. CLINX retained `PAUSED / attempted=1 / http_403_cloudflare_challenge`, with
no reply. Repeating the identical submission after the pause retained that state;
a changed question with the same ID was rejected. No resend was performed.
This verifies real P620 deployment and the outbound path, not a complete reply
roundtrip. The final focused CEF/actual-stdio suite passed all 13 checks; the
complete final suite still failed after 82 passing checks and exited with code 1.

Owner-only live records are in `build/consultation-live`; shareable evidence is
`acceptance-redacted.json` (hashed conversation/request/reply identities) and
`isolation-redacted.json`. Raw databases, preferences and account-linked IDs must
not be committed. The real website and local stdio result must be reported
separately from fixtures and from deployment of the P620 connector.

Focused checks:

```sh
# CLINX repository: ledger concurrency, duplicate/conflict, recovery and MCP.
python3 -W ignore::ResourceWarning -m unittest test_consultations test_m12 -q

# OP: real CEF renderer + actual CLINX stdio against isolated synthetic data.
OP_CEF_TEST_APP=/absolute/path/to/isolated/OPCEFIntegration.app \
OP_CEF_CONSULTATION_ONLY=1 ./script/test-cef.py

# Existing CEF, query, snapshot, notification and transport regression checks.
OP_CEF_TEST_APP=/absolute/path/to/isolated/OPCEFIntegration.app ./script/test-cef.py
```

Production `/Applications/OP.app`, its profile/data and ChatGPT Classic are not
modified by the build/test workflow. `ORION_MUTATION=NONE`.
