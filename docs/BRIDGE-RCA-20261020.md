# Consultation bridge investigation — 2026-10-20

The installed OP app was not replaced. Review and fixture bundles use independent
identities and profiles. No authentication material was extracted, copied or logged.

## 403 source: identified; official recovery: BLOCKED

Passive native CEF lifecycle metadata identified these official requests:

| Route | Method | Status | MIME | Challenge flag |
| --- | --- | --- | --- | --- |
| `/backend-api/conversations` | GET | 403 | text/html | true |
| `/backend-api/sentinel/chat-requirements/prepare` | POST | 403 | text/html | true |

`challenge` means the single fixed non-authentication response header
`cf-mitigated` equals `challenge`. [Cloudflare documents this header and HTML
response type](https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/detect-response/).
No private API is called by the bridge; these are observations of the ordinary
official webpage's own requests. Path segments outside a fixed vocabulary are
redacted; no query strings, request/response bodies or authentication headers
are recorded. Route, method, MIME and challenge are the only added fields.

Before recurrence, ordinary official conversation traffic returned HTTP 200 SSE
and a distinct native-bridge diagnostic request completed. Subsequently the
official page showed “We couldn’t load your account” and explained that its
browser check could not finish. A normal reload did not recover it.
This locates the failure at Cloudflare browser verification. The underlying
selection trigger (browser/session/network policy) has not been established.

OP reports `http_403_cloudflare_challenge` and an actionable native message.
The existing HTTP latch, exact conversation checks, live generation evidence,
stable readable body and protected-cache agreement remain mandatory. No auxiliary
403 is ignored, no challenge is bypassed and no authentication/fingerprint is
changed. A normal restart later restored readable history, but the next real
send triggered the challenge again. Stable official recovery is still blocked.
The old paused request was
explicitly cancelled with retained history and was never resent.

## Cancellation diagnostic: FAIL, unresolved

With the pinned CEF `154.0.34+g14c5a08`, the focused cancellation probe reports
`UR_FAILED`, raw error `-3`, zero encoded body bytes. In the complete suite the
same action reports `UR_FAILED`, raw error `-2`, 33 encoded bytes, about 100 ms
after starting the fetch. The server's delayed close occurs later. The test
requires exactly `-3`; it remains unchanged and fails.

The [pinned CEF callback implementation](https://github.com/chromiumembedded/cef/blob/14c5a08/libcef/browser/net_service/resource_request_handler_wrapper.cc)
sets the response error directly from the network completion status before
calling `OnResourceLoadComplete`. OP records that original value and performs
no cancellation normalization. The precise upstream origin of `-2` in the full
suite has not been proven. The byte-count correlation is evidence, not proof
of a particular internal race.

Controlled experiments removed the deliberate Content-Length mismatch, kept a
valid stream open until the peer closed, waited for an actual body chunk and
then aborted. A separate next-task abort was also tried. Full runs still
returned `-2` while the focused run returned `-3`; the server observed peer
closure. These unsuccessful fixture edits were reverted. No sleep, error
rewriting, assertion relaxation, case omission or engine upgrade is presented
as a fix. The runner now returns a nonzero exit status on a failed report.

## P620 deployment: PASS; website roundtrip: BLOCKED

The immutable composed release `op-consultations-c4756ec3700d` overlays only the
consultation extension and its tests on the actual previously deployed source.
It preserves remote native-forwarding/workspace-policy changes that were absent
from the local baseline. The canonical repository's unrelated dirty changes
were retained. No second long-lived repository was created.

Remote validation: 67 selected tests passed; existing public tool schemas were
unchanged, five consultation tools were added, and the catalog has 20 tools.
Actual deployed stdio initialized with version
`native-conversation-relay-consultations-v1`. The existing cloud capability tool
independently returned the new source root and running MCP process. Both health
and readiness endpoints were healthy after activation.

Activation followed an idle executions/leases check and restarted only
`clinx-tunnel.service`. Dispatcher, execution owner, provider, observer and centre
process identities remained unchanged. The shared `current` symlink and node
environment were not changed. The original launcher, overwritten canonical
source and a consistent database backup are retained in the task-owned rollback
directory. Rollback restores the launcher with an idle guard and restarts only
the tunnel; it must not restore an old whole database over newer records.

The review app successfully connected to the actual P620 stdio launcher over
the existing private SSH transport. Native binding initially refused the
challenged page. After normal restart restored readable history, the final
candidate bound the real synthetic conversation. The current Codex turn
submitted one unique P620 consultation and repeated it unchanged. OP triggered
one UI send. At 14:15:47 +0800, the official
`POST /backend-api/sentinel/chat-requirements/prepare` returned HTTP 403,
`text/html`, `challenge=true`. The page's optimistic user bubble does not prove
server acceptance. CLINX retained `PAUSED`, `attempted=1`,
`http_403_cloudflare_challenge`, with no reply. Identical submission after the
pause preserved that state; changed same-ID payload was rejected. The uncertain
request has not been resent. End-to-end acceptance and reply-driven Codex
continuation remain BLOCKED. No execution-owner claim is made.

The final source builds and strict signatures passed for both isolated bundles.
The final focused CEF/actual-stdio consultation run passed 13 checks
(`run-20261020-141146`). Full regression (`run-20261020-141322`) passed 82 checks
then failed the unchanged cancellation assertion; the runner exited with code 1.
P620 postflight verified all 396 manifest entries and unchanged service identities.

Owner-only evidence: `build/consultation-rca/403-source-redacted.json`,
`p620-mcp-readback.json`, `p620-cloud-readback.json`, `p620-activation.json`,
`p620-tests.log`, `p620-acceptance-redacted.json` and
`final-site-errors-redacted.json`; full CEF event evidence remains under
`build/CEFIntegration/evidence`. Remote manifests/activation/rollback are under
the existing task-owned `/data/artifacts/op-consultation-20261020` directory.
Raw profiles, databases, account-linked identifiers and logs are not release
content. `ORION_MUTATION=NONE`.

## User-reported recovery recheck

After the user reported official-page recovery, the existing final review app,
original P620 binding and original request were inspected again. The original
request remains PAUSED with one attempt, no user-message receipt and no reply.
Native binding/preflight still rejected `http_403_cloudflare_challenge`.
A normal official reload produced fresh HTTP 403 HTML challenge responses at
14:42:43–14:42:48 +0800, including conversation listing and model-related
requests. Readable history alone did not override the gate. No new request was
created, and the uncertain request was neither resumed nor resent. Fresh
redacted evidence is `build/consultation-rca/user-recovery-403-redacted.json`.

Additional cancellation isolation kept every original assertion intact: two
consecutive transport runs in one process passed 24 checks; execution-query
then transport passed 28 checks; reply-notification then transport passed 21
checks. These controls do not certify the failing complete sequence.
The exact Chromium `154.0.8037.98`
[URLLoader implementation](https://chromium.googlesource.com/chromium/src/+/154.0.8037.98/services/network/url_loader.cc)
reports `ERR_FAILED` when its response-body consumer closes, while the pinned
CEF proxy's client-disconnect path reports `ERR_ABORTED`. Thus cancellation has
more than one upstream completion path. This source evidence explains why a
raw `-2` must not be rewritten or promoted to success; it does not by itself
prove which upstream callback fired in the failing complete run. No test
expectation or product behavior has been changed by these isolation probes.

Keeping a second ordinary window active, and separately crashing/reloading a
companion renderer before transport, each also passed all 12 original transport
checks. The full-sequence failure has not been independently minimized or fixed.
All temporary harness edits were restored byte-for-byte. The fixture bundle was
rebuilt from the unchanged final source and both isolated bundles passed strict
signature verification. Final Review protection logic and the original uncertain
P620 request were unchanged. The existing cloud capability tool again returned
the deployed consultation release and the same MCP process.

At the final UI recheck, the original request's marker and `OP_P620_SUM=58`
were visible in the official conversation. Native status still reported the
Cloudflare block, while P620 retained PAUSED, one attempt and no verified reply.
The screenshot observation was not used to bypass native validation or write a
manual COMPLETED result. This supersedes any assumption that there was no
visible assistant text; the verified MCP reply remains absent. See
`user-recovery-visible-reply-redacted.json` and
`user-recovery-request-redacted.json` in the owner-only evidence directory.
The restored original transport harness passed all 12 checks again; the final
Review executable and native-library hashes remained unchanged throughout.
