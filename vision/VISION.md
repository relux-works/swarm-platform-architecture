# Swarm platform: target architecture (vision)

Status: PROPOSAL by the solution architect, 2026-10-05. Not canon. Sources: `00-owner-concept.md` (intent), `research/INVENTORY-OURS.md` (OURS), `research/INVENTORY-IVANS.md` (IVANS), `research/herdr-study.md` (HERDR), `research/tb-keeper-answer-2026-10-05.md` (TBK). Diagrams: `diagrams/` (C4 in `c4/`, sequences in `plantuml/sequence/`).
Per TBK, this design and Ivan's R191 package cover the same layer. Both should go to ONE architecture review, not run as two parallel designs.

## 1. Goals and non-goals

Goals:
1. A lightweight platform of small, minimally coupled modules: session manager, context manager + context bridge, launcher, trust, remote harness, and a few supporting services. Each module has one job and a named contract.
2. One launcher for every agent: local or remote, interactive or headless. Every launch gets a manifest-declared environment (instructions, skills, tools/MCP), and Claude/Codex auth survives the home relocation.
3. Agent I/O is wrapped. External plugins (Matrix/a2a, goals, later XMPP, Telegram, the board) inject into an agent's context and consume its output through one provider interface behind one trust gate.
4. Contexts are portable. Crash, reboot, refresh, model change or takeover restore a session from a unified handoff package, and a spawned child can receive a slice of it.
5. A "smart Ralph loop": an agent can set and clear its own goal, and a goal provider nudges it through stdin until it is done or blocked.
6. Phase 0 runs on parts that exist today. New code is written only where nothing exists.

Non-goals (for this platform):
- The board. It returns later as a flow plugin behind the placeholder in §4.9. Task-board keeps running as it is meanwhile.
- Our own agent runtime or harness (curator-agent-runtime / Apiary is deferred, IVANS §8).
- A cross-host session mesh (`ax` mesh). `ax` stays an optional terminal backend and protocol peer (TBK (2)).
- A new trust library: we compose mandates and curator-trust (IVANS §4).
- Binding to one carrier. Matrix is the first provider, not a dependency of any core module.
- Answering harness dialogs blindly. An unknown screen state parks the session; it never sends a blind Enter (HERDR §4).

## 2. Modules

| # | Module | Responsibility (one line) | Shape |
|---|---|---|---|
| M1 | Session manager | Holds harness processes alive (start/stop/park/restart/reboot-restore) and nothing else; it delegates I/O and context to M2 | Per-user supervisor + one holder per session |
| M2 | Context manager | The only writer to a session's stdin and the only reader of its stdout: harness adapters, a normalized event journal, inject/observe, snapshot/restore/slice in the unified format | Library inside the holder + journal store |
| M3 | Context bridge | Plugin host: runs in/out providers, applies the trust gate, routes envelopes to M2 and output to providers, serves agent "tails" | Separate process per user, out-of-process plugins |
| M3.x | Providers | Matrix/a2a (in/out), goal provider (smart Ralph loop), terminal/attach, later XMPP/Telegram/board | Plugin processes (JSONL over stdio) |
| M4 | Launcher | Turns a LaunchRequest into a running session: resolves the manifest into a relocated tool home, routes the model, takes a limits slot, builds one plan, targets local or remote, binds I/O and an optional context slice | CLI + library (`swarm launch`) |
| M5 | Trust | Answers "who is this, and what may they do": signed operator input, pinned identities, mandates/grants, replay checks, capability tokens | Library + `mandate` CLI + key store |
| M6 | Remote harness | Runs a harness on another host while tools run locally in a jail; a launch target of M4 | `rwh` + worker-jail |
| S1 | Model router | Picks runtime/model/effort per task class and difficulty | curator-model-router |
| S2 | Network profiles | Named egress policies applied to launches, plus a conformance probe | curator-network-profiles |
| S3 | Provider limits / host semaphore | Machine-wide slots for providers and validation suites, rate limits, validation FIFO | Extracted from task-board |
| S4 | Product registry / keeper | Products, projects, project bindings (repo, hosts, rooms), keeper process registry, `up` after reboot | curator-keeper registry + a2a spaces |
| S5 | Chat structure (a2a) | Spaces, rooms, threads, identities and cards on Matrix; the mailbox behind the Matrix provider | a2a-swarm |
| S6 | Environment / skill registry | Profiles, Skillfile/lock, skill packages, MCP requirements for manifests | Curator + curator-skill-registry |
| S7 | Ops bridges | host-hygiene and reboot-restore bridges, runner-control (CI runners), inference-manager (local serving) | Existing, wrapped only |

Coupling rules: M1 never reads content. M2 never talks to a carrier. Providers never touch stdin; they emit envelopes to M3, and M3 calls M2 after the trust gate. M4 is the only composer of launch plans (one construction site, Decision 0019) and never holds a process after handing it to M1 or M6. The modules share no stores; they pass data only through the contracts in §4.

## 3. Product and space structure on the modules

| Layout role (owner) | Session kind | Launch | I/O bindings (providers) | Supervision |
|---|---|---|---|---|
| Meta-keeper | Interactive, long-lived, local | `swarm launch --manifest meta-keeper --mode interactive` | Matrix: `#lobby`, `#broadcast`, `#system`; goal provider; terminal attach | M1 policy `always-restart`; S4 `up` after reboot |
| Product keeper `X_keeper` (Space X, not a repo) | Interactive, long-lived, local | `--manifest product-keeper --project X` (cwd = product dir) | Matrix: `#X-lobby`, `#X-broadcast`, `#X-system`; goal provider | Same; registered in S4 under product X |
| Project orchestrator (one repo) | Interactive, local or remote | `--manifest orchestrator --project X/<repo>` [`--target remote:<host>`] | Matrix: `#X-<project>`; goal provider | Restart with takeover from the last handoff |
| Worker | Headless, bounded lifetime | Spawned by an orchestrator: `--mode headless --parent <id> [--context slice:<ref>]` | Pinned to a thread or a new room in `#X-<project>`, or none (result via report/patch) | Exits with a result; not restarted |
| Remote worker | Headless or standing, remote | `--target remote:<host>` → M6 (`rwh run` or `rwh worker`) | Same as worker; rwh relays I/O to M2 | rwh guards (budget, lifetime) + M1 view |

Project attachment of remotes (owner open question): a declarative **project binding** in S4 `{project, repo, ref policy, allowed hosts, jail project, rooms, allow_from, manifest}`. M4 reads it for `--target remote` and passes rwh its flags (`--project`, `--jail-project`, `--room`, `--allow-from`), which today are hand-written in plists (OURS §5.7).

## 4. Interface contracts

### 4.1 Launcher (M4)
- `plan(LaunchRequest) -> LaunchPlan` is a dry run that returns a value and starts nothing (agents-management `Plan`). `launch(LaunchRequest) -> {session_id, target, plan_hash}`.
- `LaunchRequest`: `manifest` (profile ref) · `runtime` (claude|codex|muse|pi) · `mode` (interactive|headless) · `target` (local | remote:<host>) · `project` (binding id) · `task_class` or explicit `model/effort` · `context` (none | slice:<handoff ref> | full:<handoff ref>) · `io_bindings[]` (provider id + config) · `goal?` · `policy` (restart, lifetime, budget) · `parent?`.
- Steps: S6 resolves the manifest into a launch-env fragment (tool home, instructions, skills, MCP) → S1 route → S2 profile → S3 `acquire` → agents-management builds the plan → local: M1 `start`, remote: M6 → M3 `bind` per io_binding → if `context`, M2 `restore`.
- **Manifest** (one format for local and remote): `instructions[]`, `skills[]` (Skillfile refs, inlined for remote bundles), `tools[]`/`mcp[]`, `tails[]` (bridge CLIs to expose), `network_profile`, `home_mode` (tool-home | full-home), `permissions`. It is a superset of the Curator profile, and the rwh `bundle.json` is its remote rendering.

### 4.2 Session manager (M1)
- `start(plan, policy) -> session_id`, `stop`, `status`, `list`, `attach/detach` (humans only), `park(reason) -> handoff_ref`, `resume(session_id | handoff_ref)`, `restart(controlled)`, `takeover(session_id, new_plan?)`.
- `channel(session_id) -> duplex` is granted only to M2 through a capability token.
- Events: `session.started|exited|crashed|parked|resumed|restored`. Restart re-runs the exact stored plan by hash; flags are never rebuilt (ash §A7/§A8).

### 4.3 Context manager (M2)
- `open(session_id, adapter)`, where `adapter` is `claude-stream-json | codex-app-server | muse-serve | pty-preserve`.
- `inject(session_id, Envelope, lane=next_turn|steer|interrupt) -> receipt{queued|delivered|outcome_unknown|refused}`. Delivery happens only at a turn boundary, or as an adapter-native steer; `blocked` or `unknown` state refuses delivery and parks the session.
- `observe(session_id) -> stream<OutputEvent>` (`turn.started`, `text`, `tool_call`, `turn.completed`, `state: working|idle|blocked|unknown`).
- `snapshot(session_id, scope=full|slice(selector)) -> HandoffPackage`, `restore(HandoffPackage, session_id, strategy=preserve|rebuild)`.

### 4.4 Unified context format: the handoff package (v0)
`{schema:"swarm-handoff/0", session_id, lineage[parent, previous], created_at, reason(park|crash|reboot|refresh|takeover|slice), harness{runtime, version, native_session_id?, transcript_ref?}, plan_hash, manifest_ref, project{binding, repo, ref, workdir, dirty_patch_ref?}, summary (agent-authored park note or generated), goal{text, until, state, nudges}, open_items[], events_tail (normalized journal, bounded), io_bindings[{provider, config, cursor}], signature (host key)}`.
- **preserve**: same runtime → native resume (`--resume`/`resume <id>`) with the stored plan, then replay the envelopes not yet delivered.
- **rebuild**: another runtime, a corrupt transcript, or a slice → a fresh session primed with `summary + goal + open_items + events_tail` as the first framed turn.
- A slice for a child contains `summary` (or a selector-filtered part), the goal and the needed open items. It never contains provider cursors or credentials.

### 4.5 Bridge and provider plugin interface (M3)
- Transport: a long-lived child process speaking JSONL over stdio. Its manifest and probe follow the ax provider protocol (SPEC §7). We diverge from ax on lifetime: one process per provider rather than one per operation, because Matrix subscriptions are long-lived.
- Host → plugin: `describe`, `bind{binding_id, session_id, config, secret_ref}`, `unbind`, `output{binding_id, OutputEvent}`, `tail{binding_id, Tail}`, `receipt{envelope_id, status}`, `shutdown`.
- Plugin → host: `manifest{id, version, directions[in|out], tails[], config_schema}`, `envelope{binding_id, Envelope}`, `cursor{binding_id, opaque}`, `health`, `log`.
- `Envelope`: `{id, provider, channel, thread?, sender, signature?, received_at, kind(message|nudge|notice|command), body, reply_to}`. Delivery is at-least-once: the provider keeps a durable cursor (for Matrix, the a2a mailbox), and M2 dedupes by `id`.
- **Trust gate** (agent-session-bridge, 5 ordered checks): signature → pinned identity → grant/mandate scope → freshness/replay → deterministic checks. It returns one of four verdicts:
  - `authoritative`: operator-signed; delivered as a user turn.
  - `host_authored`: goal nudges and notices from the session's own providers; delivered plain.
  - `untrusted`: delivered as data inside an `UNTRUSTED PEER EVENTS` frame with provenance (the a2a content boundary kept).
  - `reject`: not delivered.
- **Tails** (agent → bridge): a CLI declared in the manifest (`swarm-tail`). It authenticates with a per-session capability token (`SWARM_SESSION_TOKEN`) on the bridge socket. Commands: `goal set <text> [--until <predicate>] [--max-nudges N]`, `goal clear --done|--blocked <reason>`, `goal status`, `post <binding> <text>`, `park <note>`. Stdout markers are never parsed as commands, because echoed peer text could forge them.

### 4.6 Goal provider (smart Ralph loop)
- States: `none → active → done | blocked | exhausted`, kept in M2's store and carried in the handoff package.
- On `turn.completed` + `idle` with an active goal, it sends a `nudge` envelope: the goal text, progress so far, and how to finish (`swarm-tail goal clear --done` / `--blocked`).
- Guards:
  - `max_nudges` and a minimum interval;
  - an S3 budget;
  - a no-progress detector (two turns with no tool calls or the same output → `blocked`);
  - protocol rule 32: no continuation while only parked work remains.
- `blocked` and `exhausted` go to the out providers (for example `#X-system`). The goal source is the agent itself, the launcher (`goal` in the LaunchRequest) or, later, a board binding.

### 4.7 Trust (M5)
- `verify(envelope|act) -> verdict` (curator-trust `verify`), `granted(actor, scope)`, `mandate consume <id>` for privileged steps: identity ensure, full-home launch, remote attach, new room creation.
- Capability tokens per session are scoped to the session's own subtree. Same-UID is a guardrail, not a boundary (curator-trust §0).

### 4.8 Supporting services
| Service | Contract |
|---|---|
| S1 router | `route(task_class, difficulty, runtime?) -> {runtime, model, effort, reason}`; shadow mode logs only |
| S2 network | `resolve(profile) -> egress policy`; `probe(adapter)` for conformance; M6/worker-jail enforce it remotely |
| S3 limits | `acquire(resource, weight, ttl) -> lease`, `release(lease)`, `queue(validation_job)` (FIFO); one host-wide semaphore |
| S4 registry | `products()`, `projects(product)`, `binding(project)`, `processes()`, `up()` (reboot restore → M1 `resume`) |
| S5 chat | `space ensure`, `room ensure`, `identity ensure` (under mandate), `card set`; naming `<host>_<project>_<role>` |
| S6 env | `env resolve <env> --profile <p> --format json -> launch-env-fragment-v3` |

### 4.9 Board placeholder (future plugin, not built)
- `FlowPlugin.on_transition(item, from, to) -> SpawnIntent{role→manifest, mode, io_bindings, goal}`. The platform executes it as `M4.launch`.
- `FlowPlugin.report(session_id, outcome)`. The goal provider can take goals from a `board` binding.
- Flow config = curator-playbook `Playbook.json` (types, nesting, lifecycles, the role per type × status).

## 5. Reuse / adapt / build

| Module | Verdict | Component(s) | Reference |
|---|---|---|---|
| M1 Session manager | ADAPT (target) / REUSE (now) | Now: tb-sessiond (live, board-keyed). Target: agent-session-host minimal core (supervisor, holder, registry, park/restart); `ax` as an optional backend | TBK (2); IVANS §3, §8; HERDR §4 (ideas only) |
| M2 Context manager | BUILD on ADAPT | Adapters ported from tb-sessiond (Claude PTY, Codex app-server) and rwh drivers (Claude stream-json, Muse); handoff from park `handoff_ref` + ax canonical events; herdr-style readiness rules with `unknown→park` | IVANS §8; OURS §3, §6; HERDR §4 ideas 1–5 |
| M3 Bridge + interface | BUILD (spec exists as direction) | agent-session-bridge design + trust gate; ax JSONL plugin protocol as the template | IVANS §4; OURS §5.3 |
| Matrix provider | ADAPT | a2a mailbox/subscriptions/`post` as the backend; `rwh worker` loop as prior art | OURS §2.1, §6 |
| Goal provider | BUILD | Ideas: Codex text directive (#480), doorbell `next_turn`, `goal set-primary` self-writes | IVANS §6, §8 |
| M4 Launcher | REUSE + ADAPT | Curator env/managed homes + agents-management plan + `curator-run` exec (REUSE); add headless mode, remote target, unified manifest, project bindings (ADAPT); agents-infra launchers are folded in | IVANS §2; OURS §2.5, §7; TBK (1) |
| M5 Trust | REUSE | mandates CLI (prototype, waits for mac-keyvault), curator-trust spec, a2a untrusted frame | OURS §2.4; IVANS §4 |
| M6 Remote harness | REUSE | rwh modes 2b/2c/2d/3 + worker-jail v1.1 | OURS §2.2, §2.3 |
| S1–S3, S6, S7 | REUSE | cmr (shadow), network-profiles v0.3.0, task-board provider-limits + validation FIFO (extract), curator + skill-registry, host-hygiene/reboot-restore bridges, runner-control, inference-manager | TBK (1) |
| S4 Registry/keeper | ADAPT | curator-keeper `keeper.toml` + `up` (spec only) + a2a product spaces | IVANS §5; OURS §2.1 |
| S5 Chat | REUSE | a2a-swarm (live) | OURS §2.1 |

## 6. Open decisions (owner and Ivan)

| # | Conflict | Recommendation |
|---|---|---|
| D1 | **HOME vs tool-home.** Owner: relocate HOME. Curator: relocate tool variables (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, XDG) and keep HOME. rwh remote: an empty HOME. | **Tool-home by default** (Curator managed homes; auth by symlink for Codex/Pi, a token or a one-time `/login` per managed home for Claude). It meets the owner's goal (exact skills/tools/instructions, auth kept) without breaking git/ssh/keychain. `home_mode: full-home` only for remote/jailed runs, where rwh already does it with authowner tokens. |
| D2 | **Non-interactive in the launcher vs board spawn.** Owner: one launcher for both. Decision 0021 §6: no headless `curator run`; children stay in `task-board spawn`. | **Launcher owns both modes** through one LaunchRequest and one plan builder. Amend 0021 §6. `task-board spawn` becomes a client of M4 (then the board plugin's spawn). Keep its `RUN-*` handle as the board's own record. |
| D3 | **Matrix vs a carrier-neutral bridge.** Owner's example: Matrix. 2026-10-02 decision: "nothing binds to Matrix", XMPP first. | **Carrier-neutral interface, Matrix as the first provider**, because a2a is live and holds the product spaces. XMPP is a second provider later; no core module imports a carrier. |
| D4 | **Native vs stdin goals for Claude.** Owner: stdin injection (Codex fails with native goals and waits). `claude-goal-runtime.md`: native `/goal`, no downgrade. | **Goal state in the goal provider; delivery by stdin nudge for all runtimes.** Native Claude `/goal` stays an adapter capability behind a manifest flag. Run both on Claude for two weeks, then decide by measured completion and stall rates. |
| D5 | **Which session holder.** tb-sessiond (live), agent-session-host (target, R191 review pending), ax (early). | **agent-session-host core = M1 + M2 adapters.** Our M1/M2 split maps onto its supervisor/holder + adapter/journal; M3 = agent-session-bridge. Settle it in one joint review with R191 (TBK). |
| D6 | **Peer content through stdin vs the a2a content boundary.** Owner: providers inject into stdin. Swarm rule: peer text never gets user authority. | **Inject, but framed.** Only operator-signed and host-authored envelopes get plain user-turn authority; peer messages go in as data frames (§4.5). |
| D7 | **Plugin form.** In-process Go vs out-of-process JSONL. | **Out-of-process, long-lived JSONL** (isolation, any language, ax-compatible manifest). Built-in Matrix and goal providers can ship in-tree but speak the same protocol. |
| D8 | **Remote workers in chat.** Protocol rule 25 says no; `rwh worker` has identities. | Remote workers talk only through M3 bindings that their orchestrator assigns. Update rule 25 to "only via a pinned binding". |
| D9 | **"Keeper" names four things.** | Use `meta-keeper`, `product keeper`, and `keeper registry` (S4). Rename the tb-keeper agent references to "Ivan's dispatcher" in platform docs. |

## 7. Phased plan

**Phase 0 (now, from existing parts; contracts on paper).**
- Launch: `curator-run` for interactive keepers/orchestrators; `task-board spawn` for headless children; `rwh run` / `rwh worker` for remote.
- Holding: tb-sessiond for board sessions; launchd + tmux for keepers (time-boxed herdr pilot optional, HERDR §4) with the reboot-restore bridge.
- I/O: a2a doorbell + `inbox` pull as the Matrix path. An outside loop `a2a wait → state idle → prompt` replaces in-session re-arming.
- Goals: text goals, plus a minimal shell goal loop on rwh/Codex sessions.
- Trust: a2a untrusted frame, worker-jail, `rwh mandate-run`.
- Limits and routing: task-board provider-limits; cmr in shadow.
- Deliverables: specs for LaunchRequest/manifest v0, handoff package v0, provider interface v0 and project binding v0 (this document §4), reviewed together with R191.

**Phase 1: one launcher.**
- `swarm launch` over Curator + agents-management with interactive/headless and local/remote:rwh targets.
- The manifest renders to Curator profiles and to rwh bundles.
- S3 is extracted from task-board; S4 holds project bindings for remotes.

**Phase 2: context manager + bridge.**
- On the agent-session-host core: Codex app-server and Claude stream-json adapters, the journal, `inject`/`observe`.
- Bridge with the trust gate, the Matrix provider (a2a backend), the goal provider and `swarm-tail`.
- Keepers and orchestrators move off the a2a hooks.

**Phase 3: portability.**
- Handoff snapshot/restore (preserve and rebuild); takeover and controlled restart; context slices for workers.
- Reboot restore through S4 `up`; attachable remote sessions via rwh worker over M2.

**Phase 4: board as a plugin.**
- FlowPlugin over curator-playbook; spawn through M4; board goals through a `board` provider binding.

## 8. Diagrams

- C4: `diagrams/c4/workspace.dsl`. Views: SystemContext, Containers, and ContextManagerComponents (manager, bridge, providers).
- Sequences in `diagrams/plantuml/sequence/`: `keeper-start`, `worker-start`, `remote-worker-start`, `matrix-message-injection`, `goal-loop`, `context-takeover`, `controlled-restart`.
