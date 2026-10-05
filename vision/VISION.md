# Swarm platform: target architecture (vision)

Status: PROPOSAL v1 by the solution architect, 2026-10-05. Not canon. Sources: `00-owner-concept.md` (intent), `research/INVENTORY-OURS.md` (OURS), `research/INVENTORY-IVANS.md` (IVANS), `research/herdr-study.md` (HERDR), `research/tb-keeper-answer-2026-10-05.md` (TBK), `research/curator-advice-2026-10-05.md` (CUR), `research/playbook/` (PB = curator-playbook spec v4.8). Diagrams: `diagrams/` (C4 in `c4/`, sequences in `plantuml/sequence/`). Flow example: `vision/flows/swarm-project.Playbook.json`.
Per TBK, this design and Ivan's R191 package cover the same layer. Both should go to ONE architecture review, not run as two parallel designs.

## 0. v1 changes (from v0)

- **Board brought in** (owner's new direction) as six minimally coupled parts B1–B6 with contracts (§5). It replaces the v0 §4.9 placeholder. It is still built last (Phase 4), but its contracts shape M3/M4 now.
- **D1 closed:** tool-home only. `home_mode`/`full-home` is dropped; an empty HOME is a sandbox property of the remote executor (CUR §1, objection 1).
- **D2 reframed:** the launcher composes only. `swarm launch` is a thin client; curator-run stays the one composer and fragment reader; M1 takes intake through `ax start --launch-plan`; exec and holding stay with M1 (CUR §2).
- **Manifest → profile mapping fixed** (§4.1): the "manifest superset" is gone (objection 2). Tools/tails go through CIP-0002 `command_environment` + CIP-0004; permissions are `native|yolo`; network is a launch field; remote bundles derive from `lock_sha256`.
- **Hosted stream launch mode:** a typed agents-management mode for M2 adapters, not argv pass-through (§4.1).
- **Goals:** never in argv or the system prompt; an agent-set goal stays agent-authored (§4.6).
- **Objections 3–5 resolved:** resume re-resolves the pin and refuses on drift (§4.2); preserve only within the same managed home (§4.4); the handoff package carries `lock_sha256` + fragment digest and never secrets (§4.4).
- **Roadmap alignment** with Gate A, fragment v4, KP and CIP-0003 (§8). Curator's open questions are in §7 with our recommendations.


## 0.1 v1.1 amendments from the board advice round (2026-10-05)

Sources: `research/tb-keeper-board-advice-2026-10-05.md` (TBK-B) and `research/curator-board-advice-2026-10-05.md` (CUR-B). No objections in principle. One hard line was adopted:

- **B2 may only NARROW, never widen.** A Playbook cannot relax kernel or platform invariants. These stay OUTSIDE B2:
  - the CR lifecycle and its state machine;
  - Story worktree isolation, checkpoint and converge, and the stale-tree check (tb-R182);
  - integrate and landing transactions: signed exact-head ff and junction proof (R69/R71, tb-R189, tb-R192);
  - the validation FIFO and machine ceilings (B6);
  - review-contract evidence (R141/R170/R161);
  - board goal revisions with `handoff_ref` (session-host §8);
  - activity and audit logs, resources and the evidence store (R185/R186).
  Landing windows and rulings are arbitration protocol, neither kernel nor flow. Flow-config validation (flow-config-load) rejects any rule that widens one of these (TBK-B §1).
- **B5 authority stays with the board.** The goal provider is the DELIVERY channel (stdin nudge). The board remains the AUTHOR and source of truth of goal revisions, and park and resume bind to them through `handoff_ref`. A provider-owned goal applies only to board-free sessions, such as the smart Ralph loop for keepers. Agenda item R2 of the joint review (TBK-B §3; CUR-B B5).
- **B3 resolves a role to a Curator profile reference with an exact pin**, not to raw skills and instructions. Each task record pins `profile_digest` next to `flow_digest`. Resume re-resolves both and refuses on drift (CUR-B B3).
- **B4 spawn:** curator-run compose-only, then `ax start --launch-plan`. The board never spells runtime flags and never reads fragments (CUR-B B4).
- **The board RECORDS but never CHOOSES** the credential mode (CIP-0003: per-home, token, helper) and the project-context mode (CIP-0002). Both are launch-plan properties (CUR-B).
- **Migration:** the flow facade over the current kernel is built in the private session-split fork (R188). It reaches live main only through the gated merge-back, and no extraction code lands before the joint review (tb-R191) (TBK-B §2).
- **Added to scope as platform services** (TBK-B §4):
  - the remote board (task-board server, export, import and transfer);
  - the evidence store (R185 L2);
  - resources with NUL hygiene (R176);
  - commit signing and identity;
  - the binary-swap discipline (R55);
  - CI runner topology and the public-repo rules (tb-R190);
  - per-host capacity (ceilings, the R193 build lock).

## 1. Goals and non-goals

Goals:
1. A lightweight platform of small, minimally coupled modules, each with one job and a named contract.
2. One launch path for every agent: local or remote, interactive or headless. One composer builds the plan, M1 runs it. The launch gets exactly the declared instructions, skills, MCP and commands (CIP-0002 strict project-context mode), and Claude/Codex auth survives through Curator tool homes.
3. Agent I/O is wrapped. Plugins (Matrix/a2a, goals, board, later XMPP and Telegram) inject into an agent's context and consume its output through one provider interface behind one trust gate.
4. Contexts are portable: crash, reboot, refresh, model change or takeover restore a session from a unified handoff package; a spawned child can receive a slice.
5. A "smart Ralph loop": an agent sets and clears its own goal, and the goal provider nudges it through stdin until it is done or blocked.
6. A board whose flows are configured outside the code (Playbook.json): types, nesting, lifecycles, guards and a role pinned per (type, status). A transition spawns the role through the same launch path.
7. Phase 0 runs on parts that exist today. New code is written only where nothing exists.

Non-goals: our own runtime/harness (curator-agent-runtime, Apiary: deferred); a cross-host session mesh (`ax` stays an optional backend and protocol peer); a new trust library (mandates + curator-trust); binding to one carrier; blind answers to harness dialogs (unknown screen state parks, HERDR §4); a full-HOME launcher mode; a second plan composer.

## 2. Modules

| # | Module | Responsibility (one line) | Shape |
|---|---|---|---|
| M1 | Session manager | Takes composed plans at intake (`ax start --launch-plan`), execs and holds harness processes (start/stop/park/restart/reboot-restore); owns exec machinery (process groups, abort fences, exit classification, retries) | Per-user supervisor + one holder per session |
| M2 | Context manager | The only writer to a session's stdin and reader of its stdout: harness adapters, a normalized journal, inject/observe, snapshot/restore/slice | Library inside the holder + journal store |
| M3 | Context bridge | Plugin host: runs in/out providers, applies the trust gate, routes envelopes to M2 and output to providers, serves tails | Separate process per user, out-of-process plugins |
| M3.x | Providers | Matrix/a2a, goal provider (smart Ralph loop), terminal/attach, board provider (B5), later XMPP/Telegram | Plugin processes (JSONL over stdio) |
| M4 | Launcher | Thin client: turns a LaunchRequest into a launch intent, gets one plan from the composer (curator-run, compose-only, over agents-management), hands it to M1 or M6, then binds I/O and an optional context slice. Never reads a fragment, never spells a flag, never execs or holds | `swarm launch` CLI + library |
| M5 | Trust | Signed operator input, pinned identities, mandates/grants, replay checks, capability tokens | Library + `mandate` CLI |
| M6 | Remote harness | Runs a harness on another host while tools run locally in a jail; a launch target of M4 | `rwh` + worker-jail |
| S1–S7 | Services | S1 model router (cmr) · S2 network profiles · S3 provider limits + validation FIFO (= B6) · S4 product registry/keeper · S5 chat structure (a2a) · S6 environment/skill registry (Curator) · S7 ops bridges | Existing, wrapped |
| B1–B6 | Board | Task store, flow config + engine, role router, spawn, board goal binding, validation/limits (§5) | Flow plugin over the platform |

Coupling rules: M1 never reads content. M2 never talks to a carrier. Providers never touch stdin; they emit envelopes to M3, and M3 calls M2 after the trust gate. curator-run is the only composer and fragment reader; agents-management is the only construction site (Decision 0019); M4 carries target, io_bindings, goal and policy only. The board imports no platform module: it calls M4 (spawn), M3 (provider protocol) and S3 only. Modules share no stores.

## 3. Product and space structure on the modules

| Layout role (owner) | Session kind | Launch | I/O bindings | Supervision | Board use (§5.6) |
|---|---|---|---|---|---|
| Meta-keeper | Interactive, long-lived, local | `swarm launch --profile meta-keeper --mode interactive` | Matrix `#lobby`, `#broadcast`, `#system`; goal; terminal | M1 `always-restart`; S4 `up` | Reads product boards (query only) |
| Product keeper `X_keeper` (Space X, not a repo) | Interactive, long-lived, local | `--profile product-keeper --project X` (cwd = product dir) | Matrix `#X-lobby`, `#X-broadcast`, `#X-system`; goal | Same; in S4 under X | Root of the product board; standing owner of the `product` role |
| Project orchestrator (one repo) | Interactive, local or remote | `--profile orchestrator --project X/<repo>` [`--target remote:<host>`] | Matrix `#X-<project>`; goal; board | Restart with takeover | Root role of the project board; goal = current story |
| Worker | Headless, bounded | Spawned by B4 or an orchestrator: `--mode headless --parent <id> [--context slice:<ref>]` | Thread or new room in `#X-<project>`, or none | Exits with a result | Owner of one (element, state) |
| Remote worker | Headless or standing | `--target remote:<host>` → M6 | Same; rwh relays I/O to M2 | rwh guards + M1 view | Same as worker |

Project attachment of remotes: a declarative **project binding** in S4 `{project, repo, ref policy, allowed hosts, jail project, rooms, allow_from, role_bindings}`. M4 reads it for `--target remote` and replaces today's hand-written rwh plist flags (OURS §5.7). `role_bindings` maps a role alias to a standing session (for example `product → X_keeper`), which B3 uses instead of spawning.

## 4. Interface contracts

### 4.1 Launcher (M4), composer and the profile mapping
- `plan(LaunchRequest) -> LaunchPlan` (dry run), `launch(LaunchRequest) -> {session_id, target, plan_digest}`.
- `LaunchRequest`: `profile` (Curator role profile) · `env` · `runtime` (claude|codex|muse|pi) · `mode` (interactive|headless) · `transport` (tty | hosted-stream:<adapter>) · `target` (local | remote:<host>) · `project` · `task_class` or `model/effort` · `permissions?` (native|yolo; silence = native) · `network_profile` · `context` (none | slice:<ref> | full:<ref>) · `io_bindings[]` · `goal?` · `native_goal?` · `policy` (restart, lifetime, budget) · `parent?` · `board_ref?` `{board, element, state, flow_digest, run_id}`.
- Steps: S4 binding → S1 route → S2 resolve → S3 `acquire` → **composer**: curator-run in compose-only mode resolves the profile (fragment v3, then v4) and asks agents-management for one Decision 0013 §3.2 plan → local: M1 intake `ax start --launch-plan -` (M1 execs and holds) | remote: M6 launch intent → M2 opens the adapter → M3 `bind` per io_binding and the goal → if `context`, M2 `restore`.
- **Hosted stream mode.** M2 adapters need a duplex channel, so agents-management gets a typed launch mode `HostedStream{adapter: claude-stream-json | codex-app-server | muse-serve}`; curator-run selects it with a flag, and an ax capability carries the duplex I/O to M1/M2. Not argv after `--` (untyped, classified headless, not reproducible on resume), and not plan stdin (one-shot, ≤64 KiB, 0013 §4).
- **Permissions transport** (0018, launcher SPEC §4.6): one place, silence = `native`; tracked `yolo` is refused until a versioned ax capability exists.
- **Profile mapping** (no manifest superset; a profile chooses what the context says, never how a process is launched, env §10.3):

| v0 manifest field | v1 home |
|---|---|
| `instructions` | profile context modules and system prompt (env §3, §5.5) |
| `skills` | profile lock skills (env §9.4) |
| `mcp` | MCP declaration packages (env §2.2); an explicitly empty strict-MCP set needs fragment v4 |
| `tools`, `tails` | CIP-0002 `command_environment` (fragment v4) + CIP-0004 (append PATH, never source files); `swarm-tail` is one such command |
| `permissions` | profile `native\|yolo` only (0018); richer rules are machine config (CIP-0006, narrow 0014) |
| `network_profile` | LaunchRequest field (S2), not profile content |
| `home_mode` | removed; empty HOME is an M6 executor sandbox property |
| native `/goal` flag | LaunchRequest `native_goal`, not profile |
| rwh `bundle.json` | derived from `lock_sha256`, never a parallel format |

### 4.2 Session manager (M1)
- Intake: `ax start <name> --provider <id> --launch-plan - --workspace <cwd>` (0013 §3, 0021 §2), the same contract curator-run's tracked handoff uses, so it hands off unchanged. M1 stores the plan, its `lock_sha256` and fragment digest.
- `stop`, `status`, `list`, `attach/detach` (humans only), `park(reason) -> handoff_ref`, `resume(session_id | handoff_ref)`, `restart(controlled)`, `takeover(session_id, new_request?)`.
- **Resume and restart re-resolve the pin** through the composer and compare `lock_sha256` + fragment digest with the stored ones. Drift refuses by default (0013 Decision 7, 0021 §7.3); the operator may accept it, which forces a `rebuild`.
- `channel(session_id) -> duplex` goes only to M2, under a capability token. Events: `session.started|exited|crashed|parked|resumed|restored|refused_drift`.

### 4.3 Context manager (M2)
- `open(session_id, adapter)`: `claude-stream-json | codex-app-server | muse-serve | pty-preserve`.
- `inject(session_id, Envelope, lane=next_turn|steer|interrupt) -> receipt{queued|delivered|outcome_unknown|refused}`. Delivery at a turn boundary or as a native steer; `blocked`/`unknown` refuses and parks.
- `observe(session_id) -> stream<OutputEvent>` (`turn.started`, `text`, `tool_call`, `turn.completed`, `state: working|idle|blocked:permission|blocked|unknown`).
- `snapshot(session_id, scope=full|slice(selector)) -> HandoffPackage`, `restore(HandoffPackage, session_id, strategy=preserve|rebuild)`.

### 4.4 Unified context format: the handoff package (v1)
`{schema:"swarm-handoff/1", session_id, lineage[parent, previous], created_at, reason(park|crash|reboot|refresh|takeover|slice), harness{runtime, version, native_session_id?, transcript_ref?}, profile{name, lock_sha256}, fragment_digest, managed_home{env_id}, plan_digest, project{binding, repo, ref, workdir, dirty_patch_ref?}, summary, goal{text, author, until, state, nudges, handoff_ref?}, open_items[], events_tail, io_bindings[{provider, config, cursor}], board_ref?, signature}`.
- **Never secrets:** no tokens (CIP-0003 `token` mode included), no `secret_ref` values, no credential paths. Providers re-resolve secrets at `bind`.
- **preserve** only when runtime, managed home (profile × env) and pin are the same: native resume with the stored plan, then replay undelivered envelopes. Session state and the Claude login are per home (env §7.4).
- **rebuild** otherwise (another profile or runtime, drift accepted, a corrupt transcript, a slice): a fresh session primed with `summary + goal + open_items + events_tail` as the first framed turn. Takeover across profiles always rebuilds.
- A slice for a child holds the summary (or a selector-filtered part), the goal and needed open items; never cursors or credentials.

### 4.5 Bridge and provider plugin interface (M3)
- Transport: a long-lived child process speaking JSONL over stdio; manifest and probe follow the ax provider protocol (SPEC §7), but one process per provider, not per operation.
- Host → plugin: `describe`, `bind{binding_id, session_id, config, secret_ref}`, `unbind`, `output{binding_id, OutputEvent}`, `tail{binding_id, Tail}`, `receipt`, `shutdown`. Plugin → host: `manifest{id, version, directions, tails[], config_schema}`, `envelope{binding_id, Envelope}`, `cursor`, `health`, `log`.
- `Envelope`: `{id, provider, channel, thread?, sender, signature?, received_at, kind(message|nudge|notice|command), body, reply_to}`. At-least-once; the provider keeps a durable cursor; M2 dedupes by `id`.
- **Trust gate** (agent-session-bridge, 5 ordered checks: signature → pinned identity → grant/mandate scope → freshness/replay → deterministic checks). Verdicts: `authoritative` (operator-signed, user turn) · `host_authored` (notices and nudge framing from the session's own providers) · `agent_authored` (text the session itself set, such as its own goal: delivered back framed as "your own note", never with operator authority) · `untrusted` (data inside an `UNTRUSTED PEER EVENTS` frame) · `reject`.
- **Tails**: `swarm-tail` on PATH via `command_environment`, authenticated by `SWARM_SESSION_TOKEN` on the bridge socket: `goal set|clear|status`, `post <binding> <text>`, `park <note>`. Stdout markers are never parsed as commands.

### 4.6 Goal provider (smart Ralph loop)
- States `none → active → done | blocked | exhausted`, kept in M2's store and carried in the handoff package.
- Goal sources: the agent (`swarm-tail`, author=agent), the LaunchRequest (author=launcher), the board (B5, author=board). `LaunchRequest.goal` goes to M3 only. It never enters argv (the launcher refuses `--goal`, 0013 §5) and never the system prompt or managed surfaces (they are hashed, env §5.6, so it would show up as drift).
- On `turn.completed` + `idle` with an active goal: a `nudge` envelope (host-authored frame; the goal text keeps its author's verdict) with progress and how to finish (`swarm-tail goal clear --done|--blocked`).
- Guards: `max_nudges` and a minimum interval; an S3 budget; a no-progress detector (two turns without tool calls or with the same output → `blocked`) that skips `blocked:permission`, which goes to M3 as an ask instead; protocol rule 32.
- `blocked`/`exhausted` go to out providers. This answers 0021 open question 5 ("notices from other sources") and is filed there.

### 4.7 Trust (M5)
- `verify(envelope|act) -> verdict`, `granted(actor, scope)`, `mandate consume <id>` for privileged steps: identity ensure, remote attach, new room creation, tracked `yolo` (once the ax capability exists).
- Capability tokens are scoped to the session's own subtree. Same-UID is a guardrail, not a boundary (curator-trust §0). Flow-version confirmation is the playbook's own trust interface (`confirmed/granted/narrowed/verify`, PB §2.4).

### 4.8 Supporting services
| Service | Contract |
|---|---|
| S1 router | `route(task_class \| needs, difficulty, runtime?) -> {runtime, model, effort, reason}`; shadow mode logs only |
| S2 network | `resolve(profile) -> egress policy`; `probe(adapter)`; M6/worker-jail enforce remotely |
| S3 limits (= B6) | `acquire(resource, weight, ttl) -> lease`, `release(lease)`, `queue(validation_job) -> evidence` (FIFO); one host-wide semaphore |
| S4 registry | `products()`, `projects(product)`, `binding(project)`, `processes()`, `up()` (reboot → M1 `resume`) |
| S5 chat | `space/room/identity ensure` (identity under mandate), `card set`; naming `<host>_<project>_<role>` |
| S6 env | `env resolve <env> --profile <p> --format json -> launch-env-fragment` (v3 now, one coordinated v4) |

## 5. Board (flow plugin)

The board is task management plus externally configured flows. It runs as a client of the platform (one board per process repo, PB §2.1; the product board lives in the product dir). Its parts:

| Part | Job | Contract (summary) | Plugin? |
|---|---|---|---|
| B1 Task store | Elements, hierarchy, status records, resources, activity. Kernel with no flow knowledge | `create/get/query`, `write_status(element, to, record, rev)` (B2 only, by capability), `attach(resource)`, `append(activity)`; events `element.*` | Board core; storage backend pluggable |
| B2 Flow config + engine | Loads Playbook.json, keeps the version in force, evaluates transitions | `load(project) -> FlowVersion{digest}`, `allowed(element)`, `transition(element, to, actor, via?) -> {record, actions[]}`, `on(event)` | Core; guards/actions/events come from module plugins (delivery module) |
| B3 Role router | On entry into a state, resolves the owner role to work | `route(element, state, flow_digest) -> Assignment{agent: LaunchRequest \| standing: session \| human: notice \| tool \| process}` | Core |
| B4 Spawn | One spawn interface over M4 | `spawn(LaunchRequest) -> RunHandle{run_id, session_id}`, `wait`, `cancel`, `events` | Platform client (no exec) |
| B5 Board goal binding | Publishes element goals to sessions and maps goal outcomes back | M3 provider `board`: `goal.publish`, `goal.outcome → transition request`, notices to human owners | M3 provider plugin |
| B6 Validation / limits | Spawn slots, validation FIFO for check sets | = S3 `acquire/release/queue` | Platform service |

### 5.1 B1 Task store
- Element `{id, type, parent, status, fields, assignment{role, assignee}, links{blockers}, rev}`; type and status are opaque strings that B2 validated.
- StatusRecord `{element, from, to, via?, actor{kind: run|human|kernel|event, id}, flow_digest, evidence_refs[], at}`, append-only. Resources: outcomes (`<ID>_results.md`), Change Request refs, `RUN-*` handles, `handoff_ref`s. Activity: comments, verdicts (`accepted|changes_requested|stop_the_line|rejected`), notices.
- Invariants it enforces itself: unique ids, existing parent, append-only history, optimistic `rev`. Everything else (nesting, statuses, who may move) is B2's.

### 5.2 B2 Flow config + engine
- Format: curator-playbook `Playbook.json` (PB §3–§7): roles (aliases → skills, people, tools, processes), entities (types, `parents`/`contains`, fields), per-type workflows (states with one owner each, transitions with guards, actions, `limit`, `on`), policy. `extends`/`uses` compose published playbooks.
- Version in force (PB §2.4): read only at the head of the default branch, validated (`curator playbook check`), active when capabilities cover the difference or a person confirms it. Role pins and transitions are workflow structure, so they always wait for a person. Until then the whole previous version runs. A board with no version runs the built-in default in legacy mode.
- `transition` evaluates guards on fresh evidence, applies `limit`, writes B1 through `write_status`, then runs actions; `spawn.owner` goes to B3.
- **Version pinning.** Every StatusRecord and `board_ref` carries the `flow_digest`. A transition is always evaluated under the version in force *at evaluation time*. A run in flight keeps its launch pin (`lock_sha256`) until it hands off. When it hands off after a version change, if its state no longer admits its role, the handoff is refused and the root orchestrator gets the element (PB §6.1). Activation is refused while elements sit in removed or renamed states without `migrations` (PB §7.1 rule 6).
- Today's dev flow and a design flow (full file: `vision/flows/swarm-project.Playbook.json`, which `extends` `task-board-default`):

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
- Input: `flow.entered{element, state, owner_role, flow_digest}`. A role is a skill plus instructions: its role skill, `data/role.json` (capability, needs, definition of done) and its Curator **role profile** (PB §8.1: role skills reach only their role's runs).
- `agent`: if S4 `role_bindings` maps the alias to a standing session (for example `product → X_keeper`), no spawn; B5 publishes the goal to it. Otherwise it builds a `LaunchRequest{profile: role profile, task_class from fields, needs → S1, mode: headless (interactive if the role says so), target from the project binding, io_bindings from policy (thread in `#X-<project>`), context: slice of the parent orchestrator when the role asks for it, goal: board, parent, board_ref}`.
- `human`: a notice through out providers to the role's people; the move waits for their act. `tool`/`process`: the board's tool executor or a hand-off (PB §6.5, §6.11), not the platform.

### 5.4 B4 Spawn
- One interface for interactive and headless, local and remote: `spawn` = `M4.launch` + a `RUN-*` record in B1. B4 never execs: curator-run composes, M1 (or M6 remotely) execs and holds, M2 opens the hosted-stream adapter, M3 binds I/O (for example a new Matrix thread or room via the Matrix provider config), M2 restores the optional context slice.
- Model choice: role `needs` + the operator's `models.toml` + project `policy.data.models` → S1. Slots come from S3.

### 5.5 B5 Board goal binding
- A board provider in M3. On spawn or standing assignment it sends `goal set` (author=board) for `{element, state}`, with `until` = the state's exit guards (outcome present, verdict recorded). The goal provider nudges through stdin as for any goal.
- `swarm-tail goal clear --done` → B5 → B2 `transition` request as actor `run` with `own_element` (guards still apply). `--blocked` → a move to `blocked` with a `block_kind`, or a notice to the orchestrator.
- **Reconciles session-host §8:** a park writes the M2 handoff package; the goal record keeps its `handoff_ref`, and B5 stores it as a B1 resource, so the next owner or resumed run gets it as a context slice. Agenda item for the R191 review: the goal ledger (board-goal-v2 `parent/primary`, `RUN-*` slots) keeps acceptance and verdicts in B1, while delivery state (active, nudges, blocked) moves to the goal provider (0021 §4: board goals live in the host).

### 5.6 B6, plugins, migration, product structure
- **B6** is S3: the validation FIFO runs the playbook's check sets (`delivery.checks-passed`, `landing`) and the provider limits give spawn slots. It is a platform service because keepers and goal nudges need it without a board (TBK (1)).
- **Platform-agnostic parts:** the playbook format and B2 modules (delivery module as a guard/action/event plugin); B5 as an M3 provider over the standard protocol; B1 storage backends. B4 and B6 are platform services the board consumes. Any other board can drive the platform through the same four calls: `M4.launch`, the M3 provider protocol, S3, S4 bindings.
- **Migration from task-board** (reuse vs replace):
  - REUSE: the pkg/board records, DSL, CLI and board-server as B1; the board-goal-v2 verdict vocabulary; `RUN-*` handles; the delivery machinery (CRs, worktrees, `accept_cr`, landing gate) as the delivery module; the default playbook as the PC1 legacy flow.
  - REPLACE: hard-coded types, ten statuses and `.roles` `start_status/end_status` → Playbook (PC1 seam, identical behaviour first); `task-board spawn` exec → B4 over M4, exec into M1; tb-sessiond → M1/M2 (agent-session-host core); notices → B5; `spawn.ceilings` → `policy.data.models` + `models.toml`; Context Registry `CTX-*` → M2 slices; provider-limits/FIFO → S3.
  - Order: PC1 seam with the default → S3 extraction → `task-board spawn` as an M4 client → B5 replaces notices and native board goals → project flows (dev + design) confirmed.
- **Product structure:** the meta-keeper only reads boards; a product keeper is the root of the product board (epics, design tasks) and the standing `product` owner; a project orchestrator is the root role of its repo board, with its goal = the current story (PB §6.7); workers own one (element, state) and end with an outcome or a verdict. Cross-board hand-off (product → project) uses playbook `process` roles (PB §6.5).

## 6. Reuse / adapt / build

| Module | Verdict | Component(s) | Reference |
|---|---|---|---|
| M1 | ADAPT (target) / REUSE (now) | Now: tb-sessiond. Target: agent-session-host core with the `ax start --launch-plan` intake and task-board's exec machinery | TBK (2); IVANS §3, §8; CUR §2 |
| M2 | BUILD on ADAPT | tb-sessiond and rwh adapters; ax canonical events; herdr readiness rules (`unknown→park`); hosted-stream mode in agents-management | IVANS §8; HERDR §4; CUR §3 |
| M3 + providers | BUILD / ADAPT | agent-session-bridge + trust gate; ax JSONL as the template; Matrix over a2a; goal provider new | IVANS §4; OURS §2.1, §5.3 |
| M4 | REUSE + thin BUILD | curator-run (add compose-only), agents-management plan, Curator profiles; `swarm launch` thin client; agents-infra launchers folded in via Gate A | IVANS §2; CUR §2, §5 |
| M5, M6 | REUSE | mandates, curator-trust, a2a untrusted frame; rwh + worker-jail | OURS §2.2–2.4 |
| S1–S7 | REUSE | cmr, network-profiles, task-board limits + FIFO (extract), Curator + skill-registry, curator-keeper (S4, spec), a2a, ops bridges | TBK (1); IVANS §5 |
| B1 | REUSE | task-board kernel storage and CLI | IVANS §6 |
| B2 | REUSE spec, BUILD | curator-playbook v4.8 (PC1 seam, validator) | PB §15 |
| B3–B5 | BUILD (small) | Role router over role profiles; spawn over M4; board provider | PB §8; IVANS §6 |
| B6 | = S3 | extracted from task-board | TBK (1) |

## 7. Open decisions (owner and Ivan)

| # | Topic | Recommendation |
|---|---|---|
| D1 | HOME vs tool-home | **Closed: tool-home only.** Exactness comes from CIP-0002 strict project-context mode, not from HOME. Empty HOME stays an M6 sandbox property. |
| D2 | Headless ownership | **Compose-only amendment of 0021 §6:** curator-run gains compose-only output for headless/hosted modes; M1 takes intake via `ax start --launch-plan`; `swarm launch` and B4 are thin clients. Exec stays with M1, per 0019 and 0021's rejected alternatives. |
| D3 | Matrix vs carrier-neutral | Carrier-neutral interface; Matrix first (a2a is live), XMPP later. |
| D4 | Native vs stdin goals | Goal state in the goal provider, delivery by stdin nudge. Native Claude `/goal` is a LaunchRequest `native_goal` flag; measure both for two weeks. File as the answer to 0021 open question 5. |
| D5 | Which session holder | agent-session-host core = M1 + M2 adapters; one joint review with R191. |
| D6 | Peer content in stdin | Inject, but framed by verdict (§4.5). |
| D7 | Plugin form | Out-of-process long-lived JSONL. |
| D8 | Remote workers in chat | Only via pinned M3 bindings; update protocol rule 25. |
| D9 | "Keeper" names four things | `meta-keeper`, `product keeper`, `keeper registry` (S4); "Ivan's dispatcher" for tb-keeper. |
| D10 | Goal ledger ownership (B5) | Acceptance in B1, delivery state in the goal provider; agenda for R191. |
| D11 | Standing sessions as role owners | Via S4 `role_bindings`, not in Playbook.json (playbooks are data and never name a process). |
| Q1 | (CUR) Is a local full HOME needed for anything CIP-0002 + tool homes leave uncovered? | **No named leak known; drop it.** Reopen only with a concrete leak. |
| Q2 | (CUR) Headless M2 permissions: `native` with prompts through M3, or wait for ax `yolo`? | **`native` now**: the adapter reports `blocked:permission`, M3 posts an ask, a signed answer comes back as an `authoritative` envelope. Remote/jailed workers move to `yolo` only with the versioned ax capability. |
| Q3 | (CUR) M1 intake through `ax start --launch-plan`? | **Yes.** M1 implements that contract, so curator-run hands off unchanged. |
| Q4 | (CUR) Remote: local Curator resolution from a launch intent, or a rendered bundle? | **Launch intent; the target host resolves Curator itself** (matches W7). Interim: rwh bundles derived from `lock_sha256`. |
| Q5 | (CUR) Unattended Claude: one login per managed home or CIP-0003 `token`? | **`token` for local unattended keepers/workers once CIP-0003 is adopted;** per-home login until then (few homes: role profile × env). Remote stays per-home login until protected lookup exists. |

## 8. Roadmap alignment and phases

Alignment with the curator roadmap (CUR §5): "fold in the agents-infra launchers" **is Gate A** through Decision 0019, with curator-roadmap M6 (infra exit, blocked by #105) and CIP-0006 as its narrow path; no parallel migration. **Fragment v4** is one coordinated revision: CIP-0002 (`project_context`, `command_environment`), CIP-0006 (settings digest, MCP `policy`), CIP-0003 metadata, an empty strict-MCP set. **KP**: curator-keeper's registry and `up` are S4, and `keeper up` already launches through `curator run --profile`. **CIP-0003** applies to M6: `token`/`helper` are refused for tracked or remote runs until the final executor does protected lookup. Decision 0014 (settings, hooks) stays out of scope until it or CIP-0006 is adopted.

- **Phase 0 (now).** `curator-run` for interactive keepers/orchestrators; `task-board spawn` for headless children; `rwh run|worker` for remote. Holding: tb-sessiond; launchd + tmux for keepers, with reboot-restore. I/O: a2a doorbell + `inbox` pull. Goals: text goals and a shell loop for rwh/Codex. Deliverables: LaunchRequest v1, handoff package v1, provider interface v0, project binding v0, board contracts B1–B6 (this document), reviewed with R191.
- **Phase 1: one launch path.** curator-run compose-only + hosted-stream mode (agents-management); `swarm launch` thin client; M1 intake via `ax start --launch-plan`; fragment v4; S3 extracted; S4 project bindings; remote via launch intent.
- **Phase 2: context manager + bridge.** Adapters and journal on the agent-session-host core; bridge, trust gate, Matrix and goal providers, `swarm-tail`. Keepers and orchestrators leave the a2a hooks.
- **Phase 3: portability.** Handoff v1 snapshot/restore with pin checks; takeover, controlled restart, slices; reboot restore through S4 `up`.
- **Phase 4: board.** PC1 seam with the default playbook (B1, B2); B4 over M4; B3 role router; B5 board provider; then the dev + design project flows.

## 9. Diagrams

- C4: `diagrams/c4/workspace.dsl`. Views: SystemContext, Containers, ContextManagerComponents, BoardComponents (B1–B6).
- Sequences in `diagrams/plantuml/sequence/`: `keeper-start`, `worker-start`, `remote-worker-start`, `matrix-message-injection`, `goal-loop`, `context-takeover`, `controlled-restart`, `board-transition-spawn`, `flow-config-load`.
