# Swarm platform: target architecture (vision)

Status: PROPOSAL **v1.3** (draft on top of v1.2; owners' call of 2026-10-07 folded in as §0). v1.2 by the solution architect, 2026-10-05. Not canon; the reviewed revision was v1.1 (fa4fbc68). Sources: `00-owner-concept.md` (intent), `research/INVENTORY-OURS.md` (OURS), `research/INVENTORY-IVANS.md` (IVANS), `research/herdr-study.md` (HERDR), `research/tb-keeper-answer-2026-10-05.md` (TBK), `research/curator-advice-2026-10-05.md` (CUR), the curator-playbook spec v4.8 (PB; external, curator repo, `research/playbook/` is **not** in this snapshot). Review round: `research/joint-review-sol-2026-10-05.md` (JR; B = the R191 package, cited H/C/F as there) and `research/pr1-reviews-2026-10-05.md` (tb-keeper = TBK-R, ivan-curator = CUR-R). Detailed contracts: `vision/contracts/*.md`. Owner decisions: `vision/DECISIONS-FOR-OWNERS.md`. Diagrams: `diagrams/`. Flow example (illustrative, non-activatable): `vision/flows/swarm-project.Playbook.json`.
This design and Ivan's R191 package cover the same layer and go to ONE architecture review (TBK). v1.2 converges on B's supervisor/holder split, host-enforced admission, delivery evidence and restart fences (JR §5).

Updated 2026-10-13: accepted architecture-review findings (2026-10-13), aligned to the canonical module contracts; no implementation or activation is claimed.

## 0. v1.3 changes (owners' call 2026-10-07, Ivan and Alexis)

Decisions of both owners, recorded in the wiki ledger (`decisions.md`, "2026-10-07 call") with the Russian digest `research/call-digest-2026-10-07.ru.md`. This section says what changes in the model; contracts are amended where noted and the diagrams are updated (`diagrams/`, new sequences listed in its README).

| Decision | Change in v1.3 |
|---|---|
| Two channels into a session: the operator's root channel (direct write into the PTY by the host process, or an attached terminal under the exclusive lease) and the gateway channel (an outside request through the trust broker); both end in the same stdin; no tmux | Already expressed by ADM §4 (`terminal.attach`, `authoritative` envelopes) and the single dispatcher writer; stated explicitly in §4.2 |
| Agents never read the carrier; the broker listens, verifies, rings the doorbell; the agent fetches through a Mailbox tool (In and Out) | M3 gains a **Decision Guard** (a small local model compares an admitted message with the addressee's grants and injection patterns before the doorbell; verdict logged with a fingerprint) and a **Mailbox** store; `swarm-tail inbox read` returns the verification record with the body |
| One OS user per autonomous agent, keepers included; the kernel is the sandbox, no Docker | New container **Agent Workplace** (OS user, private home without parent access, kernel firewall admitting only the broker and the egress proxy). Assurance mode **S** gets its path (O3 is no longer deferred); mode T remains the baseline until the isolation laboratory proves S |
| Each user gets its own key, unreachable by other agents; PKI / web of trust under the operator's root | New container **Key Keeper**: hierarchical derivation per agent identity (never per OS path), signatures and decryption over a local socket with peer-UID identification, the root and descendant signatures published; internal agents never hold private keys; external agents bring their own keys and are pinned |
| Grants and a decision model; grants updated and delegated with attenuation only | M5 gains the delegation rule: a requester may grant at most a subset of its own delegable grants; the dispatcher refuses amplification at spawn. Open items: role → identity binding at spawn, revocation latency, grants to human and external keys (digest Q16–Q19) |
| Spawns leave the board for the runtime; the board keeps its spawn interface and calls the runtime | New optional container **Launch Dispatcher**: run accounting, local capacity, OS-user lifecycle through one privileged helper; B4 becomes a client of it; without it the orchestrator calls `curator run` directly |
| Remote workplace = an OS user on our host: SSH by the pinned key, tools inside the user boundary, Mailbox for tasks, connection towards the host only; the previous component name is retired | the old container is renamed **Remote Workplace** (final name pending the owner's decision); LCH §8 wording updated accordingly |
| Provider credentials: no interception of provider traffic in the first implementation; shared material where the harness tolerates it, the one-year token where it does not | New container **Credential Broker**; LCH §7 keeps `source_ref`; the proxy-injection path is research only |
| Stable project team with idempotent bring-up; a system-administrator capability under a trust | Project binding gains `team[]` (role, identity, standing or ephemeral, max); S4 `up` brings standing members back; the privileged helper (not an agent) creates and removes users on requests carrying `user.create` |
| The board becomes remote; session logs leave git | Priority change in §8; K7 unchanged |
| Harness security prompts may be answered by the wrapper under policy | PLG §2: an allowlist of prompt kinds answered automatically under the parent's `session.approve`; everything else parks |
| Plan: spec without the board → C4 and sequences → joint review → MVP without the board (two harnesses, one subscription, one machine, the user chain, the certificate handshake, a Matrix space) → the board | §8 gains the MVP milestone before Phase 2 |

New sequences: `keeper-team-start`, `spawn-with-user`, `external-agent-onboarding`, `remote-workplace-attach` (both redrawn after Curator's CIP-0009 revision 2, with `remote-worker-join-handshake` and `remote-worker-retire`), `mailbox-delivery`, `grant-issue-and-check`, `keeper-sign`, `delegated-action-handler`, `action-namespace-registration`. The action vocabulary is a registered set of namespaces with schemas and handlers (a registry record under `registry.actions.register`); handlers are deterministic processes for OS-level effects or agents where judgement is wanted; wildcards exist only in grants. Renders are regenerated separately.

## 0. v1.2 changes (review round 2026-10-05)

Contract text lives in `vision/contracts/`: `trust-and-isolation.md` (TRU, v1.3: identities, keeper, grants, action vocabulary and handlers, workplaces, entry channels, remote workplaces, credentials), `admission-and-delivery.md` (ADM), `restart-and-takeover.md` (RST), `handoff-package.md` (HOP), `kernel-guards.md` (KG), `goals.md` (GOL), `launch.md` (LCH), `plugins-and-interactions.md` (PLG).

| Finding | Fix in v1.2 (or deferral with reason) |
|---|---|
| **A-B1** admission | Immutable signed `swarm-envelope/2` with `target`, `action`, `body_sha256`, `expires_at`, `grant_refs`, `binding{id, rev, policy_rev}`; provenance derived from the authenticated caller and binding; unsigned arrivals become doorbells; host-enforced `admit()` at every typed mutation (input, goals, approvals, bind, seed, control, attach, launch-time goal). ADM §2–§4; §4.5 |
| **A-B2** restart | Persisted admission fence (`open/closed/update_lock`) serialized with start/wake/retry/probe; drain of turns, interactions and external effects; confirmed absence before replacement; a refused or failed step ends the restore path with the fence closed; board ready evidence = committed goal revision with `handoff_ref`. RST §2–§3; diagrams `controlled-restart`, `context-takeover` |
| **A-B3** delivery | Bridge-local atomic admission + durable idempotent host enqueue (ack after fsync); states `accepted → queued → dispatched → applied \| refused \| expired \| unknown`; principal-scoped id → hash claims; reflection rejection; reconciliation of unknown outcomes before reopening; approvals never replayed; retention, clock and storage-failure rules. ADM §5; diagram `matrix-message-injection` |
| **A-B4** handoff | Recipient-authorized `swarm-handoff/2` at journal high-watermark H; allowlisted projections; secret-bearing material stays in protected source storage behind `resolve_ref(caller)`; per-item provenance; per-item reauthorization at seed; output egress projection. HOP; ADM §7 |
| **A-B5** narrow only | Kernel guard `kguard` in the mutation owners below every configurable action, reading the binary-versioned `kernel-policy/1` (K1–K8); load-time narrow check on the resolved closure; conformance suite. KG §1–§4; §5.2; diagram `flow-config-load` |
| A-M1 goal authority | B1 owns board goal revisions, slots and CAS; separate board-free ledger in the host; provider = scheduler; `clear` = proposal. GOL; §4.6 |
| A-M2 launch transaction | `swarm-launch-request/2` with `request_id`, precedence, allowed combinations, `LaunchResult`, stages `prepare → capacity → compose → admit → start → initialize → ready` with compensation; no-slot stops. LCH §2, §4; diagram `worker-start` |
| A-M3 project binding | Versioned, hashed, operator-authorized `swarm-project-binding/1`, pinned in intent, plan, RUN and handoff; rechecked at dispatch and resume. LCH §3 |
| A-M4 plugins | `swarm-plugin/1`: digest-pinned install, handles, broker secret resolution, sanitized env/fds, limits, restart recovery. PLG §1 |
| A-M5 ownership | Session Host = one codebase (supervisor + minimal holder + Context Engine package + goal ledger + journal); Bridge is a separate container; plugins are child processes; real dependency list in §2. C4 and all sequences redrawn |
| A-M6 resume | Compare first, then replay the stored secret-free plan; continuity × transport axes; native-resume preconditions; bounded rebuild fidelity. RST §3–§4 |
| A-M7 interactions | Typed `interaction.pending` + CAS `approval.answer`; exclusive human input lease; pinned readiness grammar. PLG §2–§3 |
| A-M8 flow transactions | Transition intents, idempotent spawn key, run reconciliation, `flow_generation` fence, migrations inside activation, recorded launch metadata. KG §5 |
| A-M9 Playbook example | Marked illustrative and non-activatable, with its activation preconditions; explicit `testing → to-review` path added. KG §6 |
| A-M10 Phase 0 | §8 now separates the Phase-0 **baseline** (existing paths, existing guarantees) from advertised capabilities and lists proof gates; §6 verdicts say BUILD where design/adoption work exists. **Partly deferred:** the per-prerequisite owner list needs the joint review (D-R8) |
| A-N1 traceability | Header says v1.2 and names absent normative sources. **Deferred:** repo+commit citations for PB, 0013/0018/0019/0021, CIP-0002/3/4/6 need the curator repo SHAs, which are not in this snapshot |
| A-N2 diagram boundaries | C4 split into Session Host, Bridge and plugin components; B5 drawn as a board component speaking the plugin protocol; README updated. **Deferred:** a deployment view, until D-R7/D-R8 fix the process topology |
| A-N3 new services | §4.8 table names each v1.1-scoped service, its current home and the gate. **Deferred:** named owners, to the joint review |
| TBK-R 1 migration | Operator-gated: fork, gated merge-back, operator-run R55 binary swap in the maintenance slot; no agent restarts daemons. §5.6, §8; RST §6 |
| TBK-R 2 testable narrowing | Conformance suite (one negative fixture per rule and per K, load-time and runtime) + PC1 behaviour-equivalence gate (full spm suite + regress unchanged). KG §4 |
| TBK-R 3 capacity | S3 `admit_host` with disk (R72/R167), CPU-idle (R112), build lock (tb-R193), syspolicyd (tb-R194) and slots; consulted by M4 and rechecked by the host before exec. LCH §5 |
| TBK-R 4 session token | Same-UID guardrail; scoped to the session's own bindings; passive `park` needs no mandate; D-GOALS defers agent self-goals to SH2+ G2; `post` (and `inbox read`) need a binding grant, `post` rate-limited and audited. ADM §6 |
| TBK-R 5 no-progress | Shadow mode in the D4 trial with an activation gate; a blocked result (detector or agent) on a board goal is a notice, never a transition. GOL §5, §3 |
| TBK-R 6 landing | Open item O1 in §7: shared-main landing coordination stays protocol (S5/arbitration), not B2 or B6 |
| CUR-R 1 profile pin | `profile_digest` renamed `profile_pin`; `expect_pin` on LaunchRequest, refused before intake; pin on `RUN-*`, StatusRecord, `board_ref`; role → profile in the S4 binding. LCH §2–§3; KG §5 |
| CUR-R 2 permission wire | agents-management spells session-start parameters; M2 forwards verbatim; `hosted-stream/1` refuses before any process exists; plan stdin null. LCH §6 |
| CUR-R 3 CIP-0003 | D-EXECUTOR: only the admitted agent-side executor re-resolves the protected binding and leases after the UID drop; plan carries opaque `source_ref`; board records `credential_mode` only; host and board runner have no broker client. LCH §7; §7 Q5 |
| CUR-R 4 remote | Intent carries `{profile, profile_pin}`; target composes and refuses on mismatch; cross-host compare pin only and always rebuild; no M4 bundle; standing worker needs the pin. LCH §8; diagram `remote-worker-start` |
| CUR-R 5 resume | Compare, then `ax` resume of the stored record; new plan only for rebuild; strict mode stated; CIP-0002 lease to M1. RST §3 |
| CUR-R 6 goal argv | No `--goal`; goal from JSON/stdin; remote task as M2's first turn; `native_goal` boolean. LCH §2, §8 |
| CUR-R 7 fields | `runtime` dropped; `board_ref` never reaches the composer; permissions default is the machine knob; 0019/0021 amendment proposed. LCH §2, §9 |
| D-R1 … D-R8 | One page for Alexis + Ivan: `vision/DECISIONS-FOR-OWNERS.md`. v1.2 applies the recommendations as proposals |

## 0.1 Earlier revisions (summary)

- **v1 (from v0):** board brought in as B1–B6; tool-home only (D1 closed); the launcher composes only (D2: curator-run is the one composer, M1 takes intake through `ax start --launch-plan`); the manifest superset replaced by the profile mapping (§4.1); hosted-stream mode is typed; goals never in argv or the system prompt; resume refuses on pin drift; preserve only in the same managed home; no secrets in handoffs; roadmap aligned with Gate A, fragment v4, KP and CIP-0003.
- **v1.1 (board advice):** B2 may only NARROW, never widen, the kernel and platform invariants (now enforced by KG). The board authors goals and the provider delivers (now GOL). B3 resolves a role to a Curator profile with an exact pin. B4 composes through curator-run and starts through the intake. The board records, never chooses, the credential mode (CIP-0003) and the project-context mode (CIP-0002). The flow facade is built in the private session-split fork (R188) and no extraction code lands before the joint review (tb-R191). Scope adds: remote board, evidence store, resources with NUL hygiene, commit signing, R55 binary swap, CI topology (tb-R190), per-host capacity.

## 1. Goals and non-goals

Goals:
1. A lightweight platform of small, minimally coupled modules, each with one job and a named contract.
2. One launch path for every agent: local or remote, interactive or headless. One composer builds the plan, the session host runs it. The launch gets exactly the declared instructions, skills, MCP and commands (CIP-0002 strict project-context mode), and Claude/Codex auth survives through Curator tool homes.
3. Agent I/O is wrapped. Carriers (Matrix/a2a, later XMPP and Telegram), goals and the board inject into an agent's context and consume its output through one bridge, behind admission that the host enforces.
4. Contexts are portable: crash, reboot, refresh, model change or takeover restore a session from a recipient-authorized handoff package; a spawned child can receive a slice.
5. A caller/board-authored goal loop (D-GOALS, session host §3.8): the launching caller supplies an initial goal, or the optional board/orchestrator authors board revisions; the provider schedules bounded nudges. Agent self-goals are deferred to SH2+ G2. Goal-free operation and passive park notes remain supported; no board-free agent completion path is specified.
6. A board whose flows are configured outside the code (Playbook.json), under kernel guards that a flow can only narrow. A transition spawns the role through the same launch path.
7. Phase 0 runs on parts that exist today, with their current guarantees. New code is written only where nothing exists.

Non-goals: our own runtime/harness (curator-agent-runtime, Apiary: deferred); a cross-host session mesh (`ax` stays an optional backend and protocol peer); a new trust library (mandates + curator-trust); binding to one carrier; blind answers to harness dialogs (unknown screen state parks, HERDR §4); a full-HOME launcher mode; a second plan composer; claiming a security boundary (mode S) that no path has proven.

## 2. Modules

| # | Module | Responsibility (one line) | Shape |
|---|---|---|---|
| M1 | Session host: supervisor | Plan intake (the `ax start --launch-plan` contract), session/execution registry, admission fences, host-enforced `admit()`, scheduling, restart and reconciliation, exec machinery (process groups, abort fences, exit classification, retries) | `agent-session-host` daemon, one per OS security domain |
| — | Execution holder | Owns one native process (PTY or framed pipes); controller epoch, execution generation, exclusive input lease. No goals, board, carrier or journal semantics | Minimal process per execution |
| M2 | Context Engine | Harness adapters, event normalizer, journal (host-owned store), dispatcher (the only stdin writer), snapshot/export/seed, interactions | **Internal package of the session host** (not a daemon) |
| — | Goal ledger | Board-free goal authority and delivery records for board goal revisions (GOL) | Internal package of the session host |
| M3 | Bridge | Hosts carrier/goal/board provider processes; trust gate; durable bridge-local admission; host enqueue; audience-checked outbox; tails | `agent-session-bridge`, separate daemon per user |
| M3.x | Providers | Matrix/a2a, goal provider (scheduler), terminal watch, board provider (B5 client), later XMPP/Telegram | Child processes, `swarm-plugin/1` JSONL (PLG) |
| M4 | Launcher | Thin client over the launch transaction (LCH): validate, capacity, compose via curator-run, compare `expect_pin`, hand to M1 or M6, drive initialize. Never reads a fragment or store content, never spells a flag, never execs or holds | `curator run` canonical entry; `swarm launch` optional wrapper (D-R3) |
| M5 | Trust | Exact-byte envelope verification, pinned identities, mandates/grants, revocation snapshots, replay rules, capability tokens | curator-trust + mandates |
| M6 | Remote executor | Runs a harness on another host while tools run in the remote workplace on this host (an OS user); returns the accepted pin and plan digest | `rwh` + remote workplace |
| S1–S7 | Services | S1 model router · S2 network profiles · S3 capacity: slots, per-host gates, validation FIFO (= B6) · S4 registry/keeper (project bindings) · S5 chat structure (a2a) · S6 environment/skill registry (Curator) · S7 ops bridges | Existing or specified, wrapped |
| B1–B6 | Board | Task store with kernel guards, flow config + engine, role router, spawn, board goal binding, validation/limits (§5) | Board over the platform |

Coupling rules: one writer per store, typed APIs between modules, no shared writable stores and no circular code dependencies. The holder never reads content. The Context Engine never talks to a carrier. Providers never touch stdin or host stores: they emit envelopes to M3, M3 admits and calls `host.enqueue`, and the host admits again before dispatch. M1 orchestrates handoffs only by opaque references through the Context Engine API. curator-run is the only composer and fragment reader; agents-management is the only construction site (Decision 0019); M4 carries target, io_bindings, goal and policy only.

Real dependency list (A-M5): the board calls M4 (spawn), M3 (B5 speaks the provider protocol), S3 (slots, FIFO, gates), S4 (bindings), S6 (`curator playbook check`), M5 (flow confirmation, grants) and git. M4 calls S1, S2, S3, S4, the composer, M1/M6, M3 and M5. The goal provider calls the host goal ledger and `enqueue` through M3 only. S4 `up` calls M1 `resume`. No host package imports the board or a carrier.

## 3. Product and space structure on the modules

| Layout role (owner) | Session kind | Launch | I/O bindings | Supervision | Board use (§5.6) |
|---|---|---|---|---|---|
| Meta-keeper | Interactive, long-lived, local | `curator run --profile meta-keeper` (mode interactive) | Matrix `#lobby`, `#broadcast`, `#system`; goal; terminal | M1 `always-restart`; S4 `up` | Reads product boards (query only) |
| Product keeper `X_keeper` (Space X, not a repo) | Interactive, long-lived, local | `--profile product-keeper`, binding X (cwd = product dir) | Matrix `#X-lobby`, `#X-broadcast`, `#X-system`; goal | Same; in S4 under X | Root of the product board; standing owner of the `product` role (slots, GOL §3) |
| Project orchestrator (one repo) | Interactive, local or remote | `--profile orchestrator`, binding X/<repo> [target remote] | Matrix `#X-<project>`; goal; board | Restart with takeover | Root role of the project board; goal = current story |
| Worker | Headless, bounded | Spawned by B4 or an orchestrator: LaunchRequest JSON, `parent`, `continuity seeded:<pkg>` | Thread or new room in `#X-<project>`, or none | Exits with a result | Owner of one (element, state) |
| Remote worker | Headless or standing | `target remote:<host>` → M6, intent with `profile_pin` | Same; rwh relays I/O to the Context Engine | rwh guards + M1 view | Same as worker |

Project attachment of remotes is the versioned project binding in S4 (LCH §3). It replaces today's hand-written rwh plist flags (OURS §5.7). `role_bindings` maps a role alias to a standing session (`product → X_keeper`) with `max_slots`, which B3 uses instead of spawning.

## 4. Interface contracts

### 4.1 Launcher (M4), composer and the profile mapping
- `plan(LaunchRequest) -> LaunchResult` (dry run, stops after `compose`), `launch(LaunchRequest) -> LaunchResult`, `cancel(request_id)`. Schema, precedence, allowed combinations, stages and compensation: **LCH §2–§4**.
- Steps: `prepare` (S4 binding, grants) → `capacity` (S3 slot + per-host gates; no slot = `queued`, the path stops) → `compose` (curator-run compose-only resolves the profile and asks agents-management for one Decision 0013 §3.2 plan; compare `expect_pin`) → `admit` (M1 intake with a closed fence, or M6 launch intent) → `start` (lease transferred to the host) → `initialize` (M3 bind, seed, goal publish, token) → `ready` (fence opens).
- **Hosted stream mode:** a typed agents-management mode `HostedStream{adapter}` that also spells the session-start permission parameters; M2 forwards them verbatim; the duplex is ax capability `hosted-stream/1`, refused before any process exists; plan stdin stays null (LCH §6).
- **Permissions:** silence = `native`; the default per profile is the machine knob `permissions.<profile>` (env §12.1); tracked `yolo` refused until a versioned ax capability exists (D-R1).
- **Profile mapping** (no manifest superset; a profile chooses what the context says, never how a process is launched, env §10.3):

| v0 manifest field | home |
|---|---|
| `instructions` | profile context modules and system prompt (env §3, §5.5) |
| `skills` | profile lock skills (env §9.4) |
| `mcp` | MCP declaration packages (env §2.2); an explicitly empty strict-MCP set needs fragment v4 |
| `tools`, `tails` | CIP-0002 `command_environment` (fragment v4) + CIP-0004 (append PATH, never source files); `swarm-tail` is one such command |
| `permissions` | `native\|yolo` via the machine knob (0018); richer rules are machine config (CIP-0006, narrow 0014) |
| `network_profile` | LaunchRequest field, default from the project binding (S2) |
| `home_mode` | removed; empty HOME is a property of remote-workplace turns in M6 |
| native `/goal` | LaunchRequest `native_goal` boolean: an M2-injected first command, never a harness flag |
| rwh `bundle.json` | produced by Curator from the pin if still needed, never by M4 (LCH §8) |

### 4.2 Session host (M1)
- Intake: the `ax start <name> --provider <id> --launch-plan - --workspace <cwd>` contract (0013 §3, 0021 §2), always in strict mode. The host stores the immutable plan, `profile_pin`, fragment digest, binding pin and the effective posture. The plan carries no secret values; M1 does protected credential lookup at exec (LCH §7).
- `stop`, `status`, `list`, `attach/detach` (humans, exclusive input lease, PLG §3), `park(reason) -> handoff_ref`, `resume`, `restart(controlled)`, `takeover(logical_session_id, new_request)`. All are typed mutations behind `admit()` (ADM §4).
- **Fence and restart:** RST. Resume compares the pin and posture first, then replays the stored plan; drift refuses (strict mode); a new plan is composed only for a rebuild.
- Events: `session.started|exited|crashed|parked|resumed|restored|refused` (with step and reason).

### 4.3 Context Engine (M2, host package)
- `open(execution_id, adapter)`: `claude-stream-json | codex-app-server | muse-serve | pty-preserve`. Readiness grammar pinned per admitted harness release; unknown parks.
- `enqueue(item) -> ack{host_seq}` (called by the bridge), dispatch at a turn boundary or as a native steer, receipts `accepted|queued|dispatched|applied|refused|expired|unknown` (ADM §5).
- `observe(execution_id) -> stream<OutputEvent>` (`turn.started`, `text`, `tool_call`, `turn.completed`, `interaction.pending`, `state: working|idle|blocked:permission|unknown`); egress goes through audience projections (ADM §7).
- `export(scope, audience) -> HandoffPackage`, `seed(package, execution_id)`, `resolve_ref(ref, caller)` (HOP).

### 4.4 Unified context format
`swarm-handoff/2` (HOP): a recipient-authorized projection at a committed high-watermark, with per-item provenance, goal references instead of a mutable goal, pins (`profile_pin`; fragment digest same-host only; binding; base SHA), and references into protected source storage. Never: tokens, `secret_ref`, `source_ref`, credential paths, live commands, pending approvals, cursors. Continuity (`native_resume | seeded_rebuild | fresh`) and transport are separate axes (RST §4).

### 4.5 Bridge and provider plugins (M3)
- Plugins: `swarm-plugin/1` (PLG §1). Host → plugin: `bind{binding_handle, config}`, `unbind`, `output{binding_handle, projected event}`, `receipt`, `shutdown`. Plugin → host: `manifest`, `envelope`, `cursor`, `health`, `secret.resolve`.
- Envelope `swarm-envelope/2` and verdicts `authoritative | host_authored | agent_authored | data | quarantine | reject` (ADM §2–§3). Unsigned bodies become doorbells (D-R2). Framing is supplementary.
- Trust gate checks in order: signature over exact bytes → enrolled identity → grant scope for `action` and `target` → freshness, replay, id claim → binding revision. The host re-checks at enqueue and at dispatch.
- **Tails**: passive `swarm-tail park` (no mandate; no goal mutation), `post`, `inbox read` (binding grant; `post` rate-limited and audited), authenticated by `SWARM_SESSION_TOKEN`, a same-UID guardrail scoped to the session's own bindings (ADM §6).

### 4.6 Goals (smart Ralph loop and board goals)
GOL, D-GOALS (session host §3.8). Board goal revisions live in B1 (CAS, slots); an initial board-free goal is authored only by the launching caller at start; the host ledger retains delivery progress, and the goal provider only schedules nudges through `enqueue`. The agent account has no goal-authoring capability; self-goals await SH2+ G2, with goal-client actions/capability shape and a board-free completion path unpublished. Goal-free operation, passive park notes and SH1 board compatibility remain. A board `clear --done` is an outcome proposal; `--blocked` and detector results are notices, never transitions. The no-progress detector runs in shadow mode during the D4 trial and has an activation gate. Goals never enter argv, the system prompt or managed surfaces (env §5.6). This answers 0021 open question 5 and is filed there.

### 4.7 Trust (M5)
- v1.3: the full trust and isolation model — identities and the key keeper, grants with attenuation-only delegation, the registered action vocabulary and handlers, one OS user per agent, the three entry channels, remote workplaces and provider credentials — is in **TRU** (`contracts/trust-and-isolation.md`).
- `verify(envelope) -> verdict`, `granted(actor, action, target)`, `mandate consume <id>` for privileged steps: identity ensure, remote attach, binding revisions, plugin install, weak data mode, tracked `yolo` (once the capability exists).
- Grants used in v1.2: `session.input`, `session.approve`, `session.bind`, `session.control`, `terminal.raw`, `transcript`, binding grants for `post`/`inbox`.
- **Assurance modes** (from B): T = same-UID guardrails; S = separated boundary, not claimed by any v1.2 path. Every plan and receipt states its mode. Flow-version confirmation stays the playbook's own trust interface (PB §2.4) and cannot waive a kernel predicate.

### 4.8 Supporting services
| Service | Contract |
|---|---|
| S1 router | `route(task_class \| needs, difficulty, env?) -> {model, effort, reason}`; shadow mode logs only |
| S2 network | `resolve(profile) -> egress policy`; `probe(adapter)`; enforced by the execution owner (host, M6 / remote workplace) and rechecked on resume |
| S3 capacity (= B6) | `admit_host(host, job_class) -> lease \| refused{gate}` (disk R72/R167, CPU-idle R112, build lock tb-R193, syspolicyd tb-R194, slots), `release(lease)`, `transfer(lease, owner)`, `queue(validation_job) -> evidence` (FIFO). Bridge parser/replay budgets are separate and not in S3 |
| S4 registry | `products()`, `projects(product)`, `binding(project) -> swarm-project-binding/1`, `processes()`, `up()` (historical reboot-requester proposal; host vs registry selection remains open under the owner's admitted session lifecycle authorisation; RST §5) |
| S5 chat | `space/room/identity ensure` (identity under mandate), `card set`; naming `<host>_<project>_<role>`; carrier membership is not app authority |
| S6 env | `env resolve <env> --profile <p> --format json -> launch-env-fragment` (v3 now, one coordinated v4); compare-only pin answers for resume |

Services scoped in v1.1, with their current home and gate (A-N3; named owners deferred to the joint review):

| Facility | Current home | Gate before the platform relies on it |
|---|---|---|
| Remote board (server, export/import, transfer) | task-board board-server | stays task-board's; the platform only calls B4/B5 |
| Evidence store (R185 L2), resources with NUL hygiene (R176) | task-board | K7/K8 in `kernel-policy/1` |
| Commit signing and identity | task-board landing (R69/R71) | K3 |
| Binary-swap discipline (R55) | operator procedure | RST §6; cutover in §8 |
| CI runner topology, public-repo rules (tb-R190) | relux-ci | outside the platform; named dependency |
| Per-host capacity, build lock (tb-R193) | task-board limits | S3 `admit_host` (LCH §5) |

## 5. Board (flow plugin)

The board is task management plus externally configured flows, under kernel guards. It is a client of the platform (one board per process repo, PB §2.1; the product board lives in the product dir).

| Part | Job | Contract (summary) | Shape |
|---|---|---|---|
| B1 Task store + kernel | Elements, hierarchy, status records, goal revisions, resources, activity; **kernel guards K1–K8** | `create/get/query`, `write_status(TransitionProposal)` (kguard first), `goal.revise(CAS)`, `attach`, `append`; events `element.*` | Board core; storage backend pluggable |
| B2 Flow config + engine | Loads Playbook.json, keeps the version in force, evaluates transitions into proposals | `load(project) -> FlowVersion{digest, generation}`, `allowed(element)`, `propose(element, to, actor) -> TransitionProposal`, `on(event)` | Core; module guards/actions from plugins (delivery module) |
| B3 Role router | On entry into a state, resolves the owner role to work | `route(element, state, flow_digest) -> Assignment{agent: LaunchRequest \| standing: session+slot \| human: notice \| tool \| process}` | Core |
| B4 Spawn | One spawn interface over M4 | `spawn(LaunchRequest{request_id = spawn key}) -> RunHandle`, `wait`, `cancel`, `events`, `reconcile(request_id)` | Platform client (no exec) |
| B5 Board goal binding | Publishes goal revisions to sessions and maps outcome proposals back | provider protocol client of M3 (`goal.publish`, `goal.outcome` → transition request, notices) | Board component, speaks `swarm-plugin/1` to M3 |
| B6 Validation / limits | Spawn slots, per-host gates, validation FIFO | = S3 | Platform service |

### 5.1 B1 Task store and kernel
- Element `{id, type, parent, status, fields, assignment{role, assignee}, links{blockers}, rev}`; type and status are opaque strings that B2 validated, plus each state's kernel class (KG §2).
- StatusRecord `{element, from, to, via?, actor{kind: run|human|kernel|event, id}, flow_digest, flow_generation, profile_pin?, credential_mode?, project_context_mode?, evidence_refs[], at}`, append-only. Resources: outcomes (`<ID>_results.md`), CR refs, `RUN-*` handles (with `profile_pin`, `plan_digest`, `binding_digest`), `handoff_ref`s. Goal revisions (K6). Activity: comments, verdicts (`accepted|changes_requested|stop_the_line|rejected`), notices.
- B1 enforces K1–K8 itself through `kguard`, whatever the flow says (KG §1–§2). Everything else (nesting, statuses, who may move) is B2's, and B2 can only add restrictions on top.

### 5.2 B2 Flow config + engine
- Format: curator-playbook `Playbook.json` (PB §3–§7): roles, entities, per-type workflows (states with one owner and one kernel class each, transitions with guards, actions, `limit`, `on`), policy. `extends`/`uses` compose published playbooks, pinned by digest.
- Version in force (PB §2.4): read only at the head of the default branch; the resolved closure is validated (`curator playbook check`) **and narrow-checked against `kernel-policy/1`** (KG §3); active when capabilities cover the difference or a person confirms it. Role pins and transitions always wait for a person. Until then the whole previous version runs. A board with no version runs the built-in default in legacy mode.
- `propose` evaluates guards on fresh evidence and applies `limit`; B1 commits through `kguard` with the transition intent; actions run from the intent with idempotent keys; `spawn.owner` goes to B3 (KG §5).
- **Version pinning.** Every StatusRecord and `board_ref` carries `flow_digest` and `flow_generation`. A transition is evaluated under the version in force at evaluation time and re-evaluated if the generation changed before commit. Activation is one transaction (lock, migrations, version, generation). A run in flight keeps its launch pin until it hands off; if its state no longer admits its role, the handoff is refused and the root orchestrator gets the element (PB §6.1). Activation is refused while elements would be stranded.
- **Conformance:** the narrow-only suite and the PC1 behaviour-equivalence gate (KG §4) run before any flow change.
- Today's dev flow and a design flow (illustrative file `vision/flows/swarm-project.Playbook.json`, which `extends` `task-board-default`; non-activatable until KG §6 holds):

| Type | Status → pinned role (owner) |
|---|---|
| task, bug (`leaf`, today's statuses) | backlog → orchestrator · **analysis → solution-architect** · to-dev → orchestrator · **development → developer** · **testing → tester** (new) · to-review → orchestrator · reviewing → reviewer · integrating → orchestrator (`accept_cr`) · done |
| design-task (`design`) | open → orchestrator · **analysis → product** · **design → designer** · **review → product** · done |
| epic, story (`container`) | orchestrator; status aggregates from children |

```json
"design": { "initial": "open",
  "states": { "open": {"owner": "orchestrator"}, "analysis": {"owner": "product"},
              "design": {"owner": "designer"}, "review": {"owner": "product"}, "done": {"terminal": true} },
  "transitions": [ {"from": "open", "to": "analysis", "actions": ["spawn.owner"]},
    {"from": "analysis", "to": "design", "guards": ["outcome.present"], "actions": ["spawn.owner"]},
    {"from": "design", "to": "review", "guards": ["outcome.present"], "actions": ["spawn.owner"]},
    {"from": "review", "to": "design", "guards": [{"guard": "verdict", "is": "changes_requested"}], "actions": ["spawn.owner"]},
    {"from": "review", "to": "done", "guards": [{"guard": "verdict", "is": "accepted"}]} ] }
```

### 5.3 B3 Role router
- Input: `flow.entered{element, state, owner_role, flow_digest, flow_generation}`. A role is its role skill, `data/role.json` (capability, needs, definition of done) and a Curator **role profile with an exact pin**; the role → profile mapping lives in the operator-owned S4 binding (env §10.3), not in the repo Playbook.
- `agent`: if S4 `role_bindings` maps the alias to a standing session, B5 publishes the goal revision into a free slot (or it queues). Otherwise B3 builds a `LaunchRequest{request_id: spawn key, profile, expect_pin, task_class from fields, mode headless (interactive if the role says so), target and binding from S4, io_bindings from policy, continuity seeded:<slice of the parent> when the role asks, goal from the board revision, parent, board_ref}`.
- `human`: a notice through out providers; the move waits for their act. `tool`/`process`: the board's tool executor or a hand-off (PB §6.5, §6.11), not the platform.

### 5.4 B4 Spawn
- `spawn` = `M4.launch` + a `RUN-*` record attached by reconciliation (KG §5). B4 never execs: curator-run composes, the session host (or M6) execs and holds, the Context Engine opens the adapter, M3 binds I/O, the host seeds the optional slice.
- Model choice: role `needs` + the operator's `models.toml` + project `policy.data.models` → S1. Slots and per-host gates come from S3. The board records the `LaunchResult.effective` values.

### 5.5 B5 Board goal binding
- Publishes B1's goal revision `{goal_id, rev, digest}` for `{element, state}` to the session; `until` = the state's exit guards. The goal provider nudges as for any goal (GOL §3–§4).
- `goal clear --done` → outcome proposal → B2 transition request as actor `run` with `own_element`; the goal stays pending until B1 accepts or refuses. `--blocked` → a notice to the orchestrator or human owner, never a transition (TBK-R 5).
- **Session-host §8:** a park writes the HandoffPackage; B1 commits the goal revision with the `handoff_ref`, and that commit is the ready evidence for restart (RST §3). The next owner or resumed run gets it as a seed.

### 5.6 B6, plugins, migration, product structure
- **B6** is S3 (§4.8): the validation FIFO runs the playbook's check sets (`delivery.checks-passed`, `landing`), and the provider limits and per-host gates give spawn slots. It is a platform service because keepers and goal nudges need it without a board (TBK (1)).
- **Platform-agnostic parts:** the playbook format and B2 modules (delivery module as a guard/action/event plugin, always under `kguard`); B5 over the standard provider protocol; B1 storage backends. Any other board can drive the platform through `M4.launch`, the M3 provider protocol, S3 and S4 bindings.
- **Migration from task-board** (reuse vs replace):
  - REUSE: pkg/board records, DSL, CLI and board-server as B1; the board-goal-v2 verdict vocabulary and goal revisions; `RUN-*` handles; the delivery machinery (CRs, worktrees, `accept_cr`, landing gate) as the delivery module **and** the kernel predicates K1–K3; the default playbook as the PC1 legacy flow.
  - REPLACE: hard-coded types, ten statuses and `.roles` `start_status/end_status` → Playbook (PC1 seam, identical behaviour first, proven by the equivalence gate); `task-board spawn` exec → B4 over M4, exec into the session host; tb-sessiond → agent-session-host; notices → B5; `spawn.ceilings` → `policy.data.models` + `models.toml`; Context Registry `CTX-*` → handoff slices; provider-limits/FIFO → S3.
  - **Operator-gated** (TBK-R 1): every REPLACE step is built in the private session-split fork (R188), reaches live main only through the gated merge-back, and goes live only by an **operator-run cutover**: a binary swap under tb-R55 inside the operator's maintenance slot, with legacy routes sticky until then. No agent restarts daemons (agent-session-host extraction plan r2, deployment section; RST §6).
  - Order: PC1 seam with the default (equivalence gate) → S3 extraction → `task-board spawn` as an M4 client → B5 replaces notices and native board goals → project flows (dev + design) confirmed.
- **Product structure:** the meta-keeper only reads boards; a product keeper is the root of the product board and the standing `product` owner (with slots); a project orchestrator is the root role of its repo board, goal = the current story (PB §6.7); workers own one (element, state) and end with an outcome or a verdict. Cross-board hand-off uses playbook `process` roles (PB §6.5).

## 6. Reuse / adapt / build

| Module | Verdict | Component(s) | Reference |
|---|---|---|---|
| M1 + holder | ADAPT (target) / REUSE (Phase-0 baseline) | Baseline: tb-sessiond. Target: agent-session-host with intake, fences, admission and task-board's exec machinery | TBK (2); IVANS §3, §8; H:628–656 |
| M2 | BUILD | Context Engine package: adapters (from tb-sessiond and rwh), journal, dispatcher, export/seed; hosted-stream mode in agents-management | IVANS §8; HERDR §4; CUR §3 |
| M3 + providers | BUILD | agent-session-bridge, durable admission, plugin ABI; Matrix doorbell over a2a; goal provider | IVANS §4; OURS §2.1, §5.3; C:618–663 |
| M4 | REUSE + BUILD | curator-run (add compose-only: needs the 0019/0021 amendment), agents-management plan, Curator profiles; launch transaction; agents-infra launchers via Gate A | IVANS §2; CUR §2, §5 |
| M5 | BUILD on REUSE | mandates (test-key prototype; real presence and enrollment missing), curator-trust (design) | OURS §2.2–2.4; JR Phase-0 table |
| M6 | ADAPT | rwh + remote workplace (an OS user on this host); pin-carrying launch intent | OURS §2.2–2.4 |
| S1–S7 | REUSE / ADAPT | cmr, network-profiles, task-board limits + FIFO (extract and add gates), Curator + skill-registry, curator-keeper (S4, spec), a2a, ops bridges | TBK (1); IVANS §5 |
| B1 | REUSE + BUILD | task-board kernel storage and CLI; `kguard` + `kernel-policy/1` | IVANS §6; KG |
| B2 | REUSE spec, BUILD | curator-playbook v4.8 (PC1 seam, validator, narrow check) | PB §15 |
| B3–B5 | BUILD (small) | role router over pinned role profiles; spawn with intents; board provider | PB §8; IVANS §6 |
| B6 | = S3 | extracted from task-board | TBK (1) |

## 7. Open decisions and items

Conflicts with the R191 package, D-R1 to D-R8: **`vision/DECISIONS-FOR-OWNERS.md`** (for Alexis + Ivan).

| # | Topic | State / recommendation |
|---|---|---|
| D1 | HOME vs tool-home | **Closed: tool-home only.** Empty HOME is for M6 remote-workplace turns only. |
| D2 | Headless ownership | Compose-only amendment of 0019 §2–3 and 0021 §6/§8 proposed (LCH §9); exec stays with the session host. Part of D-R3. |
| D3 | Matrix vs carrier-neutral | Carrier-neutral; Matrix doorbell baseline first; XMPP if E2E is promised (D-R6). |
| D4 | Native vs stdin goals | Goal truth per GOL; delivery by stdin nudge; `native_goal` boolean; two-week trial, which also measures the no-progress detector in shadow mode. |
| D5 | Which session holder | agent-session-host with minimal holders and the Context Engine as a package (D-R7). |
| D6 | Peer content in stdin | **Changed:** unsigned → doorbell; signed peer → data frame; weak mode only as an owner exception (D-R2). |
| D7 | Plugin form | Long-lived JSONL child processes for carriers only (`swarm-plugin/1`). |
| D8 | Remote workers in chat | Only via pinned M3 bindings; update protocol rule 25. |
| D9 | "Keeper" names | `meta-keeper`, `product keeper`, `keeper registry` (S4); "Ivan's dispatcher" for tb-keeper; the a2a identity `ivan-tb-keeper` stays. |
| D10 | Goal ledger ownership | B1 revisions + host ledger + provider scheduler (GOL; D-R4). |
| D11 | Standing sessions as role owners | S4 `role_bindings` with `max_slots`, not in Playbook.json. |
| Q1 | Local full HOME needed? | No named leak; dropped. |
| Q2 | Headless permissions | `native` now: `interaction.pending` → ask → `approval.answer` with CAS (PLG §2); the posture is spelled by agents-management (LCH §6). `yolo` only with the versioned capability (D-R1). |
| Q3 | M1 intake via `ax start --launch-plan`? | Yes, as a contract the host implements; no `ax` implementation dependency. |
| Q4 | Remote resolution | Launch intent with `profile_pin`; the target composes and refuses on mismatch; no M4 bundle (LCH §8). |
| Q5 | Unattended Claude credentials | **Settled boundary (D-EXECUTOR):** `curator-run` under the agent account, later `swarma-session-runner` sharing the launch library, re-resolves the protected binding and leases after the UID drop; M1 and the board runner have no broker client. Decision 0021's adopted amendment and remaining executor publication/qualification gates are described in LCH §7; no automatic per-home fallback. |
| **O1** | **Shared-main landing coordination** (TBK-R 6) | **Open, outside the platform.** Landing windows and rulings are arbitration protocol (S5 or the protocol repo). Neither B2 nor B6 provides them; K3 only guarantees each landing's own transaction. Owner: the arbitration side (tb-keeper), to be named in the joint review. |
| O2 | `pi` runtime adapter | Deferred: no M2 adapter; `tty` interactive only. |
| O3 | Mode S | Deferred: no path claims it until a broker/OS boundary is evidenced. |

## 8. Roadmap alignment and phases

Alignment with the curator roadmap (CUR §5): "fold in the agents-infra launchers" **is Gate A** through Decision 0019, with curator-roadmap M6 (infra exit, blocked by #105) and CIP-0006 as its narrow path. **Fragment v4** is one coordinated revision: CIP-0002 (`project_context`, `command_environment`), CIP-0006 (settings digest, MCP `policy`), CIP-0003 metadata, an empty strict-MCP set. **KP**: curator-keeper's registry and `up` are S4. **CIP-0003** applies to M1 and M6: `token`/`helper` stay refused for tracked or remote runs until the final executor does protected lookup (LCH §7). Decision 0014 stays out of scope until it or CIP-0006 is adopted.

**Phase 0 is a baseline, not the platform** (A-M10). It runs existing paths with their current guarantees and claims nothing more: `curator-run` for interactive keepers/orchestrators; `task-board spawn` for headless children; `rwh run|worker` for remote; tb-sessiond, launchd + tmux for holding; a2a doorbell + `inbox` pull for I/O; text goals. It does **not** demonstrate exact declared context, one launch path, portability or the target trust boundary. Phase-0 deliverables are reviewed **contract drafts** (`vision/contracts/`), not delivered schemas.

| Phase | Builds | Proof gate before it is advertised |
|---|---|---|
| 1 One launch path | compose-only + hosted-stream in curator-run/agents-management; host intake; fragment v4; S3 with per-host gates; S4 bindings; remote intent with pin | 0019/0021 amendment adopted; `hosted-stream/1` refusal tests; pin-mismatch and binding-drift negative fixtures |
| 2 Context Engine + bridge | one board-free structured vertical: one harness, mode T, Matrix doorbell or a test producer; durable admission; interactions; `swarm-tail` | ADM negative fixtures (changed bytes under a reused id, wrong target, forged plugin author, stale approval, disk full); unknown-outcome reconciliation test |
| 3 Portability | HandoffPackage export/seed, controlled restart, takeover, reboot restore via S4 `up` | RST fence tests (crash mid-restart, refused drift ends the path, stop unconfirmed); HOP audience/secret fixtures |
| 4 Board | PC1 seam with `kguard`; B4 over M4; B3; B5; then dev + design flows | KG conformance suite + PC1 behaviour-equivalence gate; operator go |

**Cutover** of any production consumer (tb-sessiond, task-board spawn) is operator-run: private fork, gated merge-back, R55 binary swap in the maintenance slot, sticky legacy routes, rollback-reader compatibility, and observation of unknown deliveries, stalled approvals and lease leaks afterwards. A calendar window (for example October 19) is the earliest date, not an authorization (D-R8).

## 9. Diagrams

- C4: `diagrams/c4/workspace.dsl`. Views: SystemContext, Containers, SessionHostComponents, BridgeComponents, BoardComponents.
- Sequences in `diagrams/plantuml/sequence/`: `keeper-start`, `worker-start`, `remote-worker-start`, `matrix-message-injection`, `goal-loop`, `context-takeover`, `controlled-restart`, `board-transition-spawn`, `flow-config-load`.
