# Contract: admission fence, controlled restart, takeover and resume

Status: VISION v1.2 contract draft. Fixes A-B2 and A-M6 (JR), Curator reviewer suggestion 5 (resume replays the stored plan), and tb-keeper condition 1 (no agent restarts daemons). Adopts B's outline (H:405–464, H:813–831). The plain-session (board-free) park semantics are defined here because B leaves them open (H:880–883).

Updated 2026-10-13: accepted architecture-review findings (2026-10-13), aligned to the canonical module contracts; no implementation or activation is claimed.

## 1. Identities

- `logical_session_id`: stable across restarts, takeovers and reboots. Bindings, goals and handoffs attach to it.
- `execution_id` = `{logical_session_id, generation}`: one per exec. Every restart, resume or takeover creates a new generation. Tokens, approvals, input leases and dispatch records are per execution.
- `controller_epoch`: incremented each time a supervisor (re)starts. A holder accepts commands only from the current epoch. After a supervisor crash, no new writes reach any holder until reconciliation (H:645–656).

## 2. The persisted admission fence

One record per logical session in the host store, written with fsync **before** any other step of the operation that changes it:

`fence{logical_session_id, state: open | closed | update_lock, reason, op_id, epoch, set_by, set_at}`

- `open`: the dispatcher may write queued items to the session.
- `closed`: `host.enqueue` still accepts and persists (`queued`), but nothing is dispatched. `start`, `wake`, `retry`, `probe` and automatic restarts are refused unless they belong to the operation (`op_id`) that holds the fence.
- `update_lock`: the binary-swap state (tb-R55). No start of any kind; set and cleared only by the operator's maintenance procedure, never by an agent (tb-keeper condition 1).
- Fence changes are serialized with start/wake/retry/probe under one per-session lock in the supervisor. A supervisor that starts reads every fence first; a crash cannot erase a closure.
- Only a successful, eligible operation (§3 step 9) or a signed operator act `fence.open` reopens it. Explicit stops stay stopped: S4 `up`, the keeper and policy `always-restart` never restart a session whose last operator act was `stop`.

## 3. Controlled restart (also the body of resume and takeover)

| Step | Action | Failure ends the path with |
|---|---|---|
| 1 Fence | `fence.close(op_id, reason=restart)` | n/a |
| 2 Drain | Stop dispatching. Let the current turn reach its boundary (`drain_timeout`, default 10 min). Void pending interactions (`plugins-and-interactions.md` §2). Wait until the process group has no tool children. Ask the effect owners whether an external effect is in flight: kernel locks for integrate/land/push (`kernel-guards.md`), S3 build lock, open CR operations | `restart_aborted{drain}`; the old execution keeps running, the fence stays closed, operator notice. The operator decides `fence.open` or a forced stop |
| 3 Park | Ask the agent for a park note (`swarm-tail park`, `drain_timeout`), else generate a summary from the journal. Write the HandoffPackage at the committed journal high-watermark H (`handoff-package.md`). For a board session, the ready evidence is B1's acknowledgment of the committed goal revision carrying the new `handoff_ref`, not the local note | `restart_aborted{park}` |
| 4 Stop | Host requests `host_stop` under the session-scoped host admission permit → dispatcher journaled E-stop → user manager `exec.stop`. Current latest-execution receipt fencing and the account-wide generation-UID absence predicate, including escaped and OS-spawned processes, belong to user manager §4.7; stop proves process absence only. Unknown evidence retains fence, claim and capacity; recovery reuses the same effect. The host never signals directly. After reboot, reconcile boot evidence and claims through the dispatcher | `stop_unconfirmed`: fence stays closed, no replacement, operator notice |
| 5 Eligibility | Compare (below). Recheck the project binding revision and the current grants. Probe auth readiness. Check approved artifact identity, ordinary startup isolation/qualification, D-RESUME compatibility (§4), and R-STANDING harness-surface digests | `refused{pin_drift \| posture_drift \| binding_drift \| auth \| runtime \| grant}` |
| 6 Start | New execution-local generation, distinct from the account generation. Request successor `host_start` under the owner's session lifecycle authorisation and session-scoped permit; dispatcher alone invokes the privileged launcher. Each start has its own `(execution_id, controller_epoch, op_id)` claim/receipt interlock; previous claim must be confirmed absent. Fresh agent-side runner registration uses the jointly gated channel contract, whose proof format is unpublished (session host §3.3; dispatcher §12) | `start_failed`: compensate (stop, confirm absence) |
| 7 Initialize | Fresh runner checks native-lock absence under the closed fence, separately from process absence; unknown keeps delivery closed. Only then native resume, or an explicitly selected rebuild seeded from the package (`handoff-package.md` §5); bind I/O; publish authorised goals; issue a new session token; current-epoch registration and readiness (session host §3.5) | `init_failed`: compensate |
| 8 Reconcile | Resolve every `unknown` delivery (`admission-and-delivery.md` §5); void historical approvals | stays closed for any unresolved application evidence; status and authorised stop remain reachable; recovery/disposition publication remains pending |
| 9 Release | `fence.open(op_id)`; queued items dispatch in order | n/a |

**A refused or failed step ends the restore path.** Nothing after it runs: no rebind, no delivery of held items, no "restored" notice. The session state becomes `parked_refused{reason}`, the fence stays closed, and the report says which step refused. Accepting drift is a new operator operation (a new `op_id`) that always rebuilds; it does not continue the old one.

**Resume compares first, then replays the stored plan** (Curator reviewer suggestion 5; 0013 §3.4–3.5). M1 keeps the record's immutable `launch_plan` exactly as the composer returned it. The plan contains no secret values: credentials are an opaque `source_ref` re-resolved against the protected binding only by the admitted agent-side executor after the UID transition (`launch.md` §7). Step 5 asks the composer for a compare-only answer (digests, no plan) and checks:
- `profile_pin` (`works.relux.curator.profile-pin`) and `fragment_digest` (same host only), `system-modules`;
- the effective posture: permissions, network profile, credential mode, project-context mode, binding revision.

Any difference refuses. "Refuse drift" means ax **strict** mode (`system-modules: true`, 0021 §7.3), which M1 always requests for its sessions. If everything matches, M1 requests the dispatcher-owned successor using the stored record; the agent-side runner performs resume under the closed fence. A new plan is composed only for a rebuild. The CIP-0002 project-context lease is transferred to M1 at the first intake and held across restarts.

## 4. Continuity and transport are separate axes

| Continuity | Transport | Supported when |
|---|---|---|
| `native_resume` | `tty` (pty-preserve) or `hosted-stream:<adapter>` | same machine and runtime family; non-breaking semver (same major, and same minor for 0.x), with no extra qualification row or version-change probe; approved artifact identity and ordinary launch isolation/qualification; R-STANDING harness-surface digest verification; same managed home (checkout × profile × env); same profile pin; transcript integrity digest matches; exclusive custody of the native session (lock checked by the fresh agent-side runner before initialisation/resume, then held exclusively); auth ready; grants current |
| `seeded_rebuild` | `hosted-stream:<adapter>` | anything else that the recipient's audience grant allows; always across hosts, profiles or runtimes |
| `fresh` | any | no package |

Conversion between transports is not supported (no TUI transcript into a stream session). An unsupported combination refuses; there is no inferred fallback. **Rebuild fidelity is bounded**: the new execution sees the package's summary, decisions, open items and goal references, never the hidden reasoning, the full tool outputs or the harness's native todo state. The report states `fidelity: seeded` and lists what was lost.

**D-RESUME supersedes D-R5's extra version-change probe.** A different major, or different minor for 0.x, refuses native resume. Record a per-harness note for vendors known not to follow semver. A harness failure is reported as `resume-failed` to the caller, who decides the next action; there is no automatic fallback, and portable seed is not part of this path. Ordinary startup qualification, approved artifact identity, auth/grants, native locks and R-STANDING surface checks remain required (session host §§3.5–3.6; wiki decision D-RESUME).

## 5. Crash, reboot and takeover

- **Crash.** The holder reports the exit; step 4's dispatcher/user-manager account-wide absence check still runs, including escaped descendants. Then steps 3 (package from the journal at H), 5–9. Controller-only re-adoption of a qualified live runner keeps the execution identity after reconciliation; it is not replacement or adoption of a live dispatcher supervisor (session host §3.2; dispatcher §12).
- **Reboot.** The OS service manager starts the host daemon (launchd). The host reads every fence and reconciles changed `boot_id` and claims with the dispatcher before marking sessions `awaiting_restore`. The former registry-only S4 `up` route is a historical requester proposal: selection between the host and project registry remains open. Any eventual requester stays within the owner's admitted session lifecycle authorisation; the session permit selects no requester and gains no authority. Steps 5–9 and joint publication/qualification gates apply (session host §7; dispatcher §§12/16; wiki book chapters 13/14).
- **Takeover** (`takeover(logical_session_id, new_request)`): the same procedure; the new execution may use another profile or runtime, so it is always `seeded_rebuild`, and the package's audience must name the new profile pin.

## 6. Operator gating (tb-keeper condition 1)

Agents can request `restart` of **sessions** they hold a `session.control` grant for. No agent restarts, upgrades or swaps a **daemon** (session host, bridge, tb-sessiond, board-server). A daemon change is the operator's binary swap under tb-R55 inside the operator's maintenance slot: `update_lock` on every fence, stop with confirmed absence, swap, start, reconcile, release (agent-session-host extraction plan r2, deployment section).
