# Contract: launch transaction, project binding, capacity gates, credentials and the remote path

Status: VISION v1.2 contract draft. Fixes A-M2 and A-M3 (JR), Curator reviewer objections 1–4 and suggestions 6–7, and tb-keeper condition 3. Replaces the v1.1 LaunchRequest field list (VISION v1.1 §4.1). The canonical entrypoint and the headless compose-only amendment are owner decisions (D-R3; see §8).

Updated 2026-10-13: accepted architecture-review findings (2026-10-13), aligned to the canonical module contracts; no implementation or activation is claimed. This revision aligns hosted lifecycle summaries with dispatcher authority.

## 1. Roles

- **Launcher (M4)**: a thin client. It validates, checks capacity, asks the composer for one plan, compares the pin, hands the plan to the session host (local) or a launch intent to the remote executor, then drives initialization. It never reads a fragment or Curator store content, never spells a native flag, never execs or holds.
- **Composer**: curator-run (the only composer and fragment reader) + agents-management (the only native-grammar construction site, Decision 0019).
- **Session host (M1+M2)**: intake of the exact plan, admission and fences; asks the dispatcher to start/stop the agent-side executor/holder (session host §§3.2–3.5; dispatcher §12). `ax` is an optional backend and protocol peer; the host implements the `ax start --launch-plan` intake contract (0013 §3, 0021 §2) without depending on an `ax` implementation.

## 2. `LaunchRequest` `swarm-launch-request/2`

| Field | Rule |
|---|---|
| `schema`, `request_id` | `request_id` is the idempotency key; B4 passes its spawn key (`kernel-guards.md` §5). Same key, same request: the existing result |
| caller | not a field: derived from the authenticated socket and the caller's grants |
| `profile` | Curator role profile name |
| `expect_pin?` | profile pin (`works.relux.curator.profile-pin`, the lock sha256). M4 compares it with the composer's output and refuses `pin_mismatch` before intake. Digests only; no fragment is read (Curator reviewer objection 1) |
| `env` | env-id. It also determines the runtime; the v1.1 `runtime` field is **dropped** (Curator reviewer suggestion 7) |
| `mode` | `interactive \| headless` |
| `transport` | `tty \| hosted-stream:<adapter>` (`claude-stream-json`, `codex-app-server`, `muse-serve`) |
| `continuity` | `fresh \| native_resume:<logical_session_id> \| seeded:<package_id>` (replaces `context`) |
| `target` | `local \| remote:<host>` |
| `project_binding` | `{id, rev}`; the launcher resolves its digest (§3) |
| `task_class` or `model`+`effort` | exactly one. Both: `refused: conflicting_routing`. Neither: the profile default through S1 |
| `permissions?` | `native \| yolo`; silence = `native` (0018 item 5). The per-profile default is the machine knob `permissions.<profile>` (env §12.1), not profile content. Tracked `yolo` refused until a versioned ax capability exists |
| `network_profile?` | default: the project binding's `egress_profile`; else the machine default |
| `io_bindings[]` | `{provider, config_ref, audience}` |
| `goal?` | `{text, until, max_nudges}`; read from JSON on stdin or a file, **never argv**. `swarm launch` has no `--goal` flag (0013 §5; Curator reviewer suggestion 6) |
| `native_goal` | boolean: M2 injects the harness's own `/goal` command as the first turn. Never a harness flag |
| `policy` | `{restart, lifetime, budget}` |
| `parent?`, `board_ref?` | kept by M4 and the host; **never sent to the composer** (0021 §4). `board_ref = {board, element, state, flow_digest, flow_generation, run_id}` |

**Allowed combinations** (else `refused: combination`): `tty` needs `interactive`. `hosted-stream` needs the ax capability `hosted-stream/1` (§6). `native_resume` needs the conditions of `restart-and-takeover.md` §4. Runtime `pi` has no M2 adapter yet: `tty` + `interactive` only, readiness `unknown` parks (deferred).

**`LaunchResult`**: `{request_id, state: ready | queued | refused | failed, stage, code?, logical_session_id?, execution_id?, plan_digest, profile_pin, binding_digest, effective{permissions, network_profile, credential_mode, project_context_mode, assurance_mode}}`. The board records the `effective` values; it never chooses them.

## 3. Project binding `swarm-project-binding/1` (A-M3)

`{binding_id, rev, digest, product, project, repo{url, identity}, base{policy, exact_sha}, worktree_policy, dirty_policy, hosts[{name, host_key_fingerprint, security_domain}], jail_project, egress_profile, audiences[], rooms[], allow_from[], role_bindings[{role, standing_session, profile_pin_compat, max_slots}], authorized_by{mandate_ref}}`

- Operator-owned and stored in S4. A new revision needs a mandate; the role → profile mapping lives here, not in a repo Playbook (env §10.3; Curator reviewer objection 1).
- Pinned as `{id, rev, digest}` in the intent, the admitted plan, `RUN-*` and the HandoffPackage.
- Rechecked at dispatch (the host's `admit` stage) and at every resume: a different revision or digest is `refused: binding_drift`.
- `exact_sha` is resolved at dispatch from the base policy; a different landed head is `refused: wrong_base`.
- A host is identified by its key fingerprint, not its name. A first-attach mandate authorizes one binding revision only.

## 4. Stages and compensation

| Stage | What happens | On failure |
|---|---|---|
| `prepare` | schema, combinations, caller grants, binding resolve | `refused{code}` |
| `capacity` | S3 slot + per-host gates (§5) | `queued{handle}` or `refused: capacity:<gate>`. **The path stops here**; a queued request resumes from `capacity` when the handle fires |
| `compose` | curator-run compose-only → plan, `profile_pin`, fragment digest; compare `expect_pin` | `refused: pin_mismatch \| capability_unavailable` |
| `admit` | host intake: plan stored, binding and gates rechecked, fence created **closed** | `refused{code}` |
| `start` | host requests `host_start` under its admitted permit; the dispatcher invokes the privileged launcher and the agent-side executor/holder starts after the UID drop; capacity lease **transferred to the host** | compensate: `host_stop` through the dispatcher's journaled `exec.stop`; release only after confirmed account-wide absence; unknown retains fence, claim and capacity |
| `initialize` | bind I/O, seed (`handoff-package.md` §5), goal publish, session token, readiness probe. No input reaches the harness before this stage ends | compensate: unbind, `host_stop` through dispatcher `exec.stop`, release lease only after confirmed account-wide absence; unknown retains fence, claim and capacity; `failed{stage}` |
| `ready` | fence opens; queued input dispatches | n/a |

`cancel(request_id)` before `ready` runs the same compensation. A bind failure can therefore not leave an orphan process.

## 5. Per-host capacity gates (tb-keeper condition 3)

S3 is more than a semaphore: `admit_host(host, job_class) → ok{lease} | refused{gate}` with these gates:

| Gate | Rule | Source |
|---|---|---|
| `disk` | free space on the workspace and store volumes above the host ceiling | R72, R167 |
| `cpu_idle` | CPU idle above the threshold over the window | R112 |
| `build_lock` | one build at a time on the Mac mini; the lease holds the lock | tb-R193 |
| `syspolicyd` | job classes that create fake executables (`job_class: fake_exec_suite`) are refused on hosts flagged with the syspolicyd bug | tb-R194 |
| `slots` | provider slots and the validation FIFO | B6 |

M4 consults `admit_host` at the `capacity` stage. The host re-checks the same gates immediately before requesting dispatcher `host_start` (`start`), because time passes between them. For a remote target, the gates of the target host apply.

<a name="6-hosted-stream-mode-and-its-permission-wire-ivan-curator-objection-2"></a>

## 6. Hosted-stream mode and its permission wire (Curator reviewer objection 2)

- agents-management gets a typed launch mode `HostedStream{adapter}`. It also spells the **session-start parameters** from the resolved permission mode (for example Muse `approvalMode`, the Codex app-server approval policy, the Claude stream-json permission mode) into the plan's `session_start` frames.
- M2 forwards those frames verbatim and chooses nothing.
- The duplex channel is the versioned ax capability `hosted-stream/1`. Without it the host refuses `capability_unavailable` **before any process exists** (as 0013 §3.5).
- The plan's `stdin` stays null: a non-null plan stdin is one-shot and closed (0013 §4).

<a name="7-credentials-ivan-curator-objection-3"></a>

## 7. Credentials (Curator reviewer objection 3)

- **D-EXECUTOR.** The admitted agent-side executor/holder is the broker consumer: first `curator-run` under the agent account, later `swarma-session-runner` for SH2+ sessions, sharing one launch library. After the UID transition it verifies the caller-composed immutable plan, re-resolves the destination-local protected binding, opens a fresh broker connection and obtains its lease. It does not compose or resolve profiles under the agent account. The plan carries only an opaque `source_ref`; the board records `credential_mode`, never credential material or `source_ref`. The board runner and session-host service embed no broker clients; they ask the dispatcher for execution. The host retains metadata, admission and fences.
- CIP-0003 item 5 follows the adopted narrow Decision 0021 amendment; the versioned one-shot intake and per-executor credential-injection qualification remain publication/activation gates, not a reason for automatic per-home fallback. Authority: credential broker §3.1 and session host §3.2; the exact intake grammar remains unpublished.

<a name="8-remote-path-ivan-curator-objection-4"></a>

## 8. Remote path (Curator reviewer objection 4)

- The launch intent carries `{profile, profile_pin, project_binding{id, rev, digest}, base_sha, task_ref, io}`. The target host's curator-run composes and refuses on a lock mismatch.
- Across hosts only the `profile_pin` is compared (fragment digests are host-bound) and continuity is always `seeded_rebuild` or `fresh`.
- **No M4-derived bundle.** If an interim rwh bundle is needed, Curator produces it (on the target, from the pin); M4 never reads store content. The standing `rwh worker` branch also requires the pin; without it: refused.
- Empty HOME applies to jail turns only; a Curator launch keeps HOME (env §10.2).
- The remote `task` is delivered as M2's first turn (an `authoritative` launch-time item), not in argv or a bundle prompt.
- The remote executor returns the accepted `profile_pin` and `plan_digest`; a difference from the intent is `refused: pin_mismatch`.

<a name="9-decision-amendment-needed-ivan-curator-suggestion-7"></a>

## 9. Decision amendment needed (Curator reviewer suggestion 7)

Headless compose-only contradicts 0019 §2–3 and 0021 §6/§8 ("no headless `curator run`"). v1.2 proposes one amendment to both: curator-run gains a compose-only output for headless and hosted-stream modes; hosted start/stop go through the dispatcher at the session host's request (session host §§3.2–3.5; dispatcher §12). This is a launcher-owner decision (D-R3), not something this document adopts.
