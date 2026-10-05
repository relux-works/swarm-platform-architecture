# Inventory: Ivan's side (`ivans/`) against the owner's platform concept

Scope: the docs-only copies under `ivans/`, read against `00-owner-concept.md`. Every claim cites a path relative to the repo root. "Not found" means absent from these copies. The copies hold docs, specs and directory trees only, so "implemented" rests on the repos' own status lines, changelogs and trees. No code was run.

## 0. Summary

- **Launcher (owner §3).** This is the most mature part. Curator is released as `0.15.0-rc.3`, and `curator-run` as `v0.2.0`. Together they provide per-profile managed homes, credential passthrough and manifest-declared context, skills and MCP. Two things are missing:
  - They relocate the tool's home variables (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, XDG, `PI_CODING_AGENT_DIR`), not `HOME`.
  - They are interactive only. Non-interactive spawn lives in `task-board spawn`.
- **Session holding (owner §1).** Three overlapping things exist:
  - `tb-sessiond`: implemented, but fused into the board.
  - `agent-session-host`: a spec draft. Its "extract as is" plan was replaced on 2026-10-05 by "new minimal core plus compatibility facade".
  - `ax`: a large spec, and an implementation with no `ax` command yet.
- **Context bridge with in/out providers and a trust gate (owner §2).** This exists as an agreed *direction* plus a one-page design: `ivans/agent-session-bridge/README.md`. There is no plugin interface spec.
- **Configurable board flows (owner §4).** These are fully designed, not implemented: `curator-playbook` `Playbook.json` v4.8. Today's task-board hard-codes the dev flow.
- **Goals as stdin injection (owner §2).** A Codex text-goal change (PR #480) moves that way. Claude still uses native `/goal`.

## 1. Component table

| Component | Purpose | State | Key abstractions / interfaces | Owner-concept role |
|---|---|---|---|---|
| **curator** | Agent environment manager: skill packages, Skillfile/lock, MCP requirements, audit registry, profiles and managed homes (`ivans/curator/README.md`) | **Released.** v0.1 plan complete (`ivans/curator/README.md` "Status"). Latest entry `0.15.0-rc.3 - 2026-10-04` (`ivans/curator/CHANGELOG.md`) | `curator profile install/use`, `curator env resolve <env> --repair --format json` → `launch-env-fragment-v1/v2/v3`. Managed homes at `~/.curator/environments/<profile>/<env-id>`. Umbrella dispatch `curator <noun>` → `curator-<noun>` on trust roots (`ivans/curator/docs/second-operator.md` §4–6) | Launcher, context half: HOME-like relocation plus manifest-declared instructions, skills and MCP |
| **curator-agent-launcher** (`curator-run`) | "Just run it". Composes the Curator fragment, the agents-management interactive plan and optional `ax` tracking, then execs (`ivans/curator-agent-launcher/SPEC.md` §1) | **Released binary `v0.2.0` (2026-10-02); spec `0.5.0-draft`** (`ivans/curator-agent-launcher/CHANGELOG.md`, `README.md` "Install") | CLI `curator-run <env-id> [--profile] [--model] [--effort] [--permissions native\|yolo] [--name] [--ax-profile] -- <native>` (SPEC §3). A 6-step composition (SPEC §4). Tracked handoff `ax start <name> --provider <id> --launch-plan - --workspace <cwd>` (SPEC §4.6) | Launcher, execution half; interactive spawn only |
| **curator-spec** | Normative Curator protocol `1.0.0-rc.14` plus decisions (`ivans/curator-spec/README.md`) | Draft release candidate. Adopted: 0017, 0018, 0019, 0021. Proposed, not adopted: 0014, 0015, 0016. 0010, 0012 and 0013 are marked "Proposed" in their headers (`ivans/curator-spec/decisions/*`). Normative `protocol/environments.md` revision 1 exists | Four planes (Decision 0010 §10): **context** = Curator, **spawn** = agents-management, **session** = ax, **execution** = launcher. Plus `ax start --launch-plan` (0013 §3), one construction site (0019 §1) and "sessions enter through `curator run`" (0021 §1–2) | Contracts for launcher ↔ session manager |
| **curator-agent-runtime** | Spec for a runtime that executes agents from a Curator environment (SessionPlan, CallPlan, receipts), plus the "Apiary" distributed design (`ivans/curator-agent-runtime/README.md`, in Russian) | **Spec only.** "В репозитории нет реализации runtime" ("there is no runtime implementation in the repo") (README). Apiary drafts in `docs/drafts/apiary/` | `protocol/runtime.md`, `tool-interface.md`, `approval.md`. Minimal roadmap: AgentHost adapter → pool of local and remote agent loops (`docs/drafts/apiary/minimal-roadmap.md` §10) | Long-term own harness / remote pool; not needed for the minimal platform |
| **curator-keeper** | Node "main loop": a process registry `keeper.toml`, routing, starting and supervising one root orchestrator per process, `keeper up` after a reboot (`ivans/curator-keeper/README.md`) | **Draft v0.5.1. Nothing implemented** (README "Status"; `spec/track.md` KP0–KP5) | `keeper` CLI wraps `curator session …`, `curator run`, `task-board` (spec §7.2). Five launch layers (§7.3). Supervision matrix (§10.2). waggle doorbell+pull (§10.4) | Process orchestration (the meta-keeper / product keeper of the owner's layout) |
| **curator-trust** | Who counts as a person; presence-bound confirmations; capabilities; delegated acts; companion app; separate OS account (`ivans/curator-trust/README.md`) | **Draft v0.4. Nothing implemented** (README "Status") | Four answers to the kernel: `confirmed(version)`, `granted(...)`, `narrowed(...)`, `verify(act)` (`spec/trust.md` §2). Separate agent OS account plus broker (§12) | Trust gate policy behind the bridge |
| **curator-playbook** | `Playbook.json`: roles, entities (types and nesting), workflows (states and transitions), policy; validator `curator playbook check` (`ivans/curator-playbook/README.md`) | **Draft v4.8, "freeze candidate". Nothing implemented** (README "Status"). JSON examples in `examples/` | Role kinds `agent\|human\|tool\|process` (spec §4.2), aliases bound to skills (§4.1), `extends`/`uses` (§7), "roles are skills" (§8), default playbook = today's task-board (§14) | **Board flow configuration** (owner §4) |
| **agent-session-host** | Keeps long-lived sessions: start a harness with a goal, attach/detach, doorbell, events (`ivans/agent-session-host/README.md`) | **Spec draft v0.3 (2026-09-27)** (`spec/session-host.md` header). Strategy changed 2026-10-05 to a new minimal core (`ivans/wiki/decisions.md` "2026-10-05: the session host extraction"). The copy has no code tree (`ivans/agent-session-host/_TREE.txt`) | `ProviderHost`/`ProviderHostFactory` plus optional capabilities (spec §2.6). Contract ops start/resume/stop/status/attach/apply-goal/ack/deliver/events (§3.3). Doorbell modes (§7). Park (§8). Estop (§9). Backends `pty\|tmux\|ax` (§13) | **Session manager** (holding) |
| **agent-session-bridge** | I/O between sessions and the outside world: input producers (Matrix, XMPP, app, Telegram), output consumers, trust gate, a verification tool for the model (`ivans/agent-session-bridge/README.md`) | **Design. One README only** (`_TREE.txt` is empty) | 5-step trust gate (signature → pinned identity → grant/mandate scope → freshness/replay → deterministic checks). Unsigned input is framed as untrusted data with provenance | **Context bridge with in/out providers** |
| **agent-session-manager** (`ax`) | Implementation repo of `ax`: durable cross-host sessions | **Foundation only.** "Session, provider, terminal, mesh, and operator command behavior is not implemented or advertised" (`ivans/agent-session-manager/README.md` "Project Status"). Milestones M0–M4; M0 is done per `ivans/agent-session-host/spec/session-host.md` §13 | Spec pins and verification (`internal/specpin`). Internal packages such as `terminalbackend`, `provider`, `sshtransport`, `clonebundle` (`_TREE.txt`) | Possible future session/terminal backend |
| **agent-session-manager-spec** | Normative `ax` spec v0.7.0 (16,908 lines) | **"Prepared, unpublished"; spec only** (`ivans/agent-session-manager-spec/README.md`) | Launch, attach, takeover, fork, clone, stop/resume (SPEC §1.2). Provider plugins `ax-provider-<id>` over JSONL (§7.1–7.5). Task-board bridge `urn:ax:protocol:task-board-bridge` (§9). Mesh RPC over SSH (§11). States "not a replacement for task-board or tb-sessiond" (§1.2) | Ideas for takeover, conversion and teleport (context manager) |
| **wiki** | Ecosystem decisions, roadmap, research, collective-mode records (`ivans/wiki/_TREE.txt`) | Living docs. Latest decisions dated 2026-10-05 (`ivans/wiki/decisions.md`) | — | Source of direction (§7 below) |
| **skill-project-management-docs** (task-board) | Board CLI `task-board` plus `board-server`; spawn-first orchestration (`ivans/skill-project-management-docs/README.md`) | **Implemented and in daily use** (README; `tb-sessiond` row at README.md:1544) | Board DSL, `task-board spawn`, `tb-sessiond` Session Manager, board-goal-v2, Context Registry `CTX-*` (README.md:1875), `.roles/` | Board (later plugin) plus today's de-facto session manager and spawn |

## 2. (a) The launcher

| Topic | What exists | Source |
|---|---|---|
| `curator run` | Calls `curator env resolve <env> --repair --format json`, then execs the tool with the fragment's `CLAUDE_CONFIG_DIR`/`CODEX_HOME`, the lineup model/effort and the native args after `--` | `ivans/curator/docs/second-operator.md` §6 |
| Launch plan | agents-management `BuildLaunchWithEnvironment` in `LaunchModeInteractive` returns a plan value (`Binary, Argv, Env, Stdin, WorkDir`) that starts nothing. `curator-run` composes exactly one launch plan from it | `ivans/curator-agent-launcher/README.md` steps 4–6; `ivans/curator-spec/decisions/0013-execution-ownership-and-launch-plans.md` §1 |
| One construction site | Every argv element and context channel (MCP, system prompt, home variable) is spelled only in the agents-management plugin. Consumers (`curator-run`, task-board) never spell flags | `ivans/curator-spec/decisions/0019-fragment-consumers-and-one-construction-site.md` §1–2 |
| Fragments | `launch-env-fragment-v1`: `env`, `profile{name, lock_sha256}`, `precedence`, `system_prompt`, `mcp`. v2 adds permission selections. v3 (Muse) adds four XDG parents and **preserves inherited `HOME`** | `ivans/skill-project-management-docs/.specs/drafts/launch-profiles.md` §1 table; `ivans/curator/CHANGELOG.md` 0.15.0-rc.3 |
| Managed homes / HOME relocation | Modes `managed-home \| linked \| copied`. A managed home is per (profile × env), with surfaces symlinked from the commit-keyed store and the tool's mutable state beside them. **Relocation is through tool-specific variables, not `HOME`** | `ivans/curator-spec/decisions/0010-agent-environment-profiles.md` §4; `ivans/curator/docs/second-operator.md` §4 |
| Auth surviving relocation | Credentials are never copied: Codex/Pi `auth.json` is symlinked to the native store. Claude on macOS has a per-`CLAUDE_CONFIG_DIR` Keychain item, so a **one-time `/login` per managed home** is needed (Decision 0017 adopted) | `ivans/curator/docs/second-operator.md` §5; `ivans/curator-spec/decisions/0017-environment-credential-modes.md` |
| Profiles / manifest | A profile is a repo or dir with `agent-context.json` (root context modules = **instructions**), an optional profile-scoped `Skillfile.json` (**skills**, whose commands are the **tools**) and MCP declarations (Decision 0012) | `ivans/curator/docs/second-operator.md` §4; `ivans/curator-spec/decisions/0010-agent-environment-profiles.md` §1 |
| Skill commands inside managed homes | Open: Decision 0016 "skill command roots in managed homes" is **proposed, not adopted**. The launcher keeps `path_prepend` parsed but non-operative | `ivans/curator-spec/decisions/0016-managed-home-command-roots.md`; `ivans/curator-agent-launcher/README.md` "Environment and transport" |
| Role profiles | Each role's skills reach only its runs, through that role's Curator profile (decided 2026-09-25). `keeper up` runs `curator run <runtime> --profile <role profile>` | `ivans/curator-playbook/spec/process-configuration.md` §0; `ivans/curator-keeper/spec/keeper.md` §7.3 |
| Runtime bindings | Machine catalog `~/.curator/runtimes.toml` (provider endpoint, credential *source*, engine, windows). `--runtime` and `--profile` are separate axes | `ivans/skill-project-management-docs/.specs/drafts/launch-profiles.md` D1–D4 |
| Interactive spawn | `curator-run` uses only `LaunchModeInteractive`. "There is no headless `curator run`" | `ivans/curator-spec/decisions/0021-sessions-enter-through-curator-run.md` §6; launcher SPEC §1 |
| Non-interactive spawn | `task-board spawn --role --background --model [--reasoning-effort]` uses `claude -p`, `codex exec` or Qwen stream-JSON, with a durable `RUN-…` handle, events, directives and a wait barrier. Goal-bound owners run inside a manager-held session. task-board consumes the fragment itself (D5) | `ivans/skill-project-management-docs/references/tracked-background-spawn.md` lines 49–90; `.specs/drafts/launch-profiles.md` D5 |
| Tracked vs untracked | `ax.json` (`curator-run-ax-v1`): machine file over operator file. With tracking on, the launch always goes through `ax start`, and a failed handoff never falls back. `--untracked` was adopted in 0021 §3 but **is not in the shipped parser** | launcher SPEC §4.6; `ivans/wiki/roadmap/session-platform-draft-2026-10-03/README.md` (tb-keeper's checks) |
| Remote workers | Alexey's remote workers start with an **empty, overridden HOME** and act through a remote-bash dynamic tool. They move to Curator after the prototype. Remote harness code is not in `ivans/` | `ivans/wiki/research/call-digest-2026-09-29-evening.md` §4; `ivans/agent-session-host/spec/session-host.md` §16 note |

## 3. (b) Session holding: tb-sessiond vs agent-session-host vs ax

| Aspect | `tb-sessiond` (task-board) | `agent-session-host` | `ax` |
|---|---|---|---|
| State | Implemented (`ivans/skill-project-management-docs/README.md:1544`) | Spec v0.3. Superseded in strategy by the 2026-10-05 hybrid (c) (`ivans/wiki/decisions.md`) | Spec v0.7.0 unpublished; implementation has foundation only |
| Scope | One control plane per **board** (`BoardKey`) (`ivans/agent-session-host/spec/session-host.md` §2.1) | Planned: one host per OS user per node, one holder per session (§5) | Cross-host mesh of durable sessions (SPEC §1.2) |
| Harness handling | Claude: PTY master held **in the daemon**, so it dies on daemon restart. Codex: a private app-server per session, which survives (§2.6–2.7) | Per-session holders, re-adopted after restart (§5, §14) | Terminal backends (tmux on Unix, ConPTY on Windows) (SPEC §4) |
| Goal plane | Native: Claude `/goal tbg-…` by bracketed paste; Codex app-server goal or text directive (`ivans/skill-project-management-docs/docs/claude-goal-runtime.md`:1–66) | Moves the goal *delivery*. The ledger stays in task-board (§3.2) | Out of scope ("goal plane stays with task-board", §13) |
| Doorbell | Notices delivered only when ≥1 client is attached (§2.5) | `next_turn` / `steer` / `interrupt`, delivered when detached too (§7) | Not covered |
| Takeover | `parent/primary` slot: refusal across providers, or a TTY takeover prompt (`claude-goal-runtime.md`:9–29) | Inherits it | Graceful and forced takeover, fork, clone (SPEC §13.6–13.8) |
| Access control | One bearer token per board, readable by every agent (§2.8) | Peer creds, per-session capability tokens, a supervision matrix (§6) | SSH mutual auth, allowlisted mesh (SPEC §11) |
| CLI | `task-board session list\|status\|stop\|logs\|doctor\|restart` | `curator session …`, fronted by `keeper` (§12.1) | `ax …` (not shipped) |

The 2026-10-05 direction: a new minimal core in `agent-session-host` (supervisor, holder, registry, control API, park/restart, adapters as packages). Board goals and flows are its clients. It is built first in the private fork `skill-project-management-session-split` (`ivans/wiki/decisions.md` "2026-10-05"; `ivans/wiki/research/2026-10-05-session-core-study.md` summary).

The draft orchestrator brief adds more (`ivans/wiki/roadmap/session-platform-draft-2026-10-03/ORCHESTRATOR-BRIEF.draft.md` "Hard requirements"):
- two modes: **preserve** (native TUI under our holder) and **rebuild** (structured protocol: Codex `app-server`, Muse `serve`, Claude `-p` stream-json);
- one handoff mechanism for refresh, conversion and teleport;
- "the host imports nothing from task-board".

## 4. (c) The bridge, its plugin interface, the trust gate

| Item | Finding | Source |
|---|---|---|
| Agreed direction | Each session's I/O goes through a separate bridge with producer and consumer plugins (terminal, chat, app, mail), configured per session. Injection is opt-in per bridge profile. Bridge and host are authenticated. **"Nothing binds to Matrix."** | `ivans/wiki/decisions.md` "2026-10-02 call" |
| Module split | `agent-session-bridge` = input producers + output consumers behind one ingress trust gate | `ivans/wiki/decisions.md` "2026-10-05" |
| Plugin interface | **Not found** as a spec. The nearest templates are:<br>• ax provider plugins: JSONL over stdio, one process per op, manifest + probe, structured fail-closed errors (`ivans/agent-session-manager-spec/SPEC.md` §7.1–7.3);<br>• the host's out-of-process adapter form, which reuses that protocol and is only *proposed* (`ivans/agent-session-host/spec/session-host.md` §3.3; `.../DISCUSSION.ru.md` "Поправки tb-keeper")<br>The architect's draft has an illustrative `session_binding` YAML (inbound doorbell/direct_input, outbound views) | `ivans/wiki/roadmap/session-platform-draft-2026-10-03/architecture.md` §11.2 |
| Separation of plugin kinds | Harness adapter, transport provider and workflow integration are three separate extension axes, not one universal plugin | same, §3 |
| Trust gate | 5 ordered checks (signature, pinned identity, grant/mandate scope, freshness/replay, deterministic checks). The operator's signed messages are authoritative; everything else is untrusted data | `ivans/agent-session-bridge/README.md` |
| Trust policy | curator-trust: same-UID checks are a guardrail, not a boundary. The real boundary is a presence-bound key, plus later a separate agent OS account with a broker | `ivans/curator-trust/spec/trust.md` §0, §12 |
| Grants | Owner-signed certificates (scope, grantee key, expiry), verified per request. Built on curator-trust plus Alexey's mandates (mandates spec not in `ivans/`) | `ivans/wiki/decisions.md` "2026-10-02", "2026-10-05" |
| Carriers | XMPP is proposed as the first product carrier. waggle runs local or NATS across nodes. Matrix serves legacy collective mode | `architecture.md` §11.3–11.4; `ivans/curator-keeper/spec/keeper.md` §10.4 |
| Command gate | Proposed envelope (`command_id, actor, target, kind, grant_refs, expiry, signature`) and states `received→accepted→queued→dispatched→applied\|outcome_unknown` | `architecture.md` §9 |

## 5. (d) The keeper (process orchestration)

- **Role plus module.** A skill run by any harness, plus the deterministic `keeper` CLI. It never does process work and never writes a process's board (`ivans/curator-keeper/spec/keeper.md` §3.1–3.2, §7.1–7.2).
- **Registry.** `~/apiary/keeper.toml` with `[processes.<name>]`: `id`, `path`, `node`, `role`, `channels`. Processes are separate repos, not submodules (§5.1–5.3).
- **Start.** `keeper up` runs `curator run <runtime> --profile <role profile>` in each hive's directory, through 5 layers: `curator` → `curator-run` → agents-management plan → session host → harness (§7.3). Until the bridge exists, queens are built "with the construction task-board uses for children" (Gate A) (§7.3).
- **Supervision.** A wake/park/stop/watch/estop matrix by actor (§10.2). Park writes a note bound into the goal (`handoff_ref`) (§10.5; `ivans/agent-session-host/spec/session-host.md` §8). `keeper up` restores the node after a reboot (§10.6).
- **Messaging.** Always waggle `coord` messages: append to mailbox → host rings the doorbell → orchestrator pulls (`task-board mail read`) (§10.4).
- **State.** Nothing is implemented. KP1 = one node, terminal only (`ivans/curator-keeper/spec/track.md`).
- **Naming clash.** `tb-keeper` / `ivan-tb-keeper` in the wiki is an *agent session* (Ivan's dispatcher), not this component (`ivans/wiki/collective-mode/README.md`).

## 6. (e) The board: flows, roles, spawn, and what is hard-coded

| Item | Today (task-board) | Configurable target (curator-playbook) |
|---|---|---|
| Types / nesting | epic → story → task/bug, in code `pkg/board/types.go:13-16, 184-218` | `entities` with `parents`/`contains` (`ivans/curator-playbook/spec/process-configuration.md` §5.1, §14) |
| Statuses | Ten fixed statuses. Happy path `backlog → analysis → to-dev → development → to-review → reviewing → integrating → done`, plus `closed` and `blocked` (`ivans/skill-project-management-docs/references/statuses.md`:18–35) | Per-type `workflows` with states and transitions (§6.1–6.2) |
| Transitions | No transition table: any status may be set when its gates pass (playbook §14 table) | Declared transitions with guards, actions and events from modules (§6.3) |
| Role ↔ status | `.roles/<role>/role.md` frontmatter `start_status` / `end_status` / `dod` / `skills` (`references/roles.md`:26–45). Bundled roles include analyst, developer, reviewer, tester, solution-architect, orchestrator (`ivans/skill-project-management-docs/.roles/`) | "Each element has exactly one owner in each state." Role aliases bound to skills, people, tools or processes (§0, §4.1–4.2) — exactly the owner's "role pinned per type and status" |
| Dev machinery | Change Requests, worktrees, `integrating` entered only via `accept_cr`, landing-gate suite (playbook §14 rows) | A "delivery module" contributing guards and invariants (README "How it fits") |
| Spawn | `task-board spawn --role --background --model`, per-role model ceilings in `task-board.config.json` (`references/tracked-background-spawn.md`:68–90) | Roles state *needs*, not models. The operator binds models in `~/.curator/models.toml` (§0, §9) |
| Goals | board-goal-v2 ledger: `parent/primary` and `run/RUN-*` slots. The session can write its own goal (`task-board goal set-primary`/`update`) (`docs/claude-goal-runtime.md`:210–240) | "Short goals" (§6.7) |
| Context sharing | Context Registry `CTX-*`: provider context forks per spawn, behind `features.context_sharing` (README.md:1117, 1875) | Not covered |

**Hard-coded about the dev flow:** the type set and nesting, the ten statuses, CR → `integrating` → done, review verdicts, container aggregation, and `parent/primary` singularity (playbook §14 "Accepted differences" 1–15).

The older task-board-local playbooks draft is marked superseded by curator-playbook (`ivans/skill-project-management-docs/.specs/drafts/playbooks.md` header).

## 7. (f) Wiki interaction schemes

| # | Scheme | Location | Summary |
|---|---|---|---|
| W1 | Process isolation on one node (PlantUML deployment) | `ivans/wiki/diagrams/plantuml/deployment/process-isolation-on-one-node.puml` | One node: the main loop and its process registry in a root dir, one session host, operator files in `~/.curator/`. Each process is a git repo with `Playbook.json`, `Skillfile.json`, `task-board.config.json`, a board, exactly one root orchestrator, sub-orchestrators and runs |
| W2 | Communication layers (PlantUML sequence) | `ivans/wiki/diagrams/plantuml/sequence/communication-layers.puml` | (a) On one board, a hand-off is board records (offer/accept/result → `process.returned`). (b) Across boards, a waggle `coord.handoff-*`, with the result signed by board 2's host key. (c) Main loop ↔ orchestrator: signed request → mailbox → host rings the doorbell → orchestrator pulls; child runs report only to their orchestrator. (d) NATS across nodes |
| W3 | Delegation of human acts (PlantUML sequence) | `ivans/wiki/diagrams/plantuml/sequence/delegation-of-human-acts.puml` | The project's `policy.delegation` allows/never. A person grants with OS user auth. The orchestrator acts "on behalf of" within ceilings; otherwise the act goes pending to the person via the main loop. Revocation takes effect at once |
| W4 | KV-cache plane: five diagrams (ownership component, anchor-save, context fan-out, rework after model swap, slot/snapshot states) | `ivans/wiki/research/kv-cache-orchestration/diagrams/plantuml/*` | Local-engine KV snapshot/restore for context fan-out and rework (proposed, partly unmeasured) |
| W5 | Session platform C2/C3 (ASCII in markdown) | `ivans/wiki/roadmap/session-platform-draft-2026-10-03/architecture.md` §4 | C2: UI/CLI/keeper/board → authenticated Session API → supervisor (journal, inbox/outbox) → per-session holder → harness; Session Bridge → E2E connector → XMPP; Curator Launch Service → admitted plan → host. C3: API → authn → authz → command inbox → scheduler → adapter → holder I/O → normalizer → journal → snapshot → subscriptions |
| W6 | Session platform Mermaid set (C1, C2, C3, launch, command, recovery, migration) | Referenced in `.../session-platform-draft-2026-10-03/README.md` "Диаграммы" ("Diagrams") | **Not found**: the README says `diagrams/*.mmd` were not handed to the wiki |
| W7 | Text flows: local fresh launch (7 steps), remote launch intent, supervisor restart/re-adoption, command pipeline | `architecture.md` §6.1–6.2, §7.3, §9.2 | Remote: the phone sends a launch *intent* to the target node, whose local Curator resolves it. The host is not a second composer |

The `wiki/architecture.md` page shows W1–W3 (`ivans/wiki/architecture.md`). Related component diagrams outside the wiki:
- `ivans/agent-session-host/diagrams/plantuml/` (one-host-per-node, restart-survival, park-and-resume, doorbell-delivery, session-start-today, emergency-stop);
- `ivans/curator-keeper/diagrams/plantuml/` (installation-and-first-run, one-node-system, several-nodes, request-routing, reboot-restore);
- `ivans/agent-session-manager-spec/diagrams/` (Structurizr C4 plus takeover, cloning, mesh, session-state).

## 8. Reuse / adapt / replace map for the minimal platform (no board)

| Owner module | Existing piece | Verdict | Why |
|---|---|---|---|
| Launcher: env, HOME, manifest | Curator profiles, managed homes, `env resolve` fragment, credential passthrough | **REUSE** | Released; per-tool home relocation keeps auth (`ivans/curator/docs/second-operator.md` §4–6) |
| Launcher: plan spelling | agents-management construction site (outside `ivans/`) | **REUSE** | Decision 0019 adopted |
| Launcher: exec / interactive | `curator-run` | **REUSE** | Released v0.2.0 |
| Launcher: non-interactive + remote | `task-board spawn` exec machinery; Alexey's remote-worker harness (not in `ivans/`) | **ADAPT** | Interactive-only by design; exec mode is board-bound (`launch-profiles.md` D5). Needs a board-free spawn interface and a remote target |
| Launcher: true `HOME` override | none (Curator relocates tool vars; Muse preserves `HOME`) | **ADAPT** | Owner asks for HOME relocation; remote workers already use an empty HOME (call digest §4) |
| Launcher: skill commands on PATH | Decision 0016 | **ADAPT** | Not adopted |
| Session manager (holding) | `tb-sessiond` adapters (Claude PTY, Codex app-server) | **ADAPT** (port selectively) | Proven mechanics, but board-keyed, with 45 board-import files (`architecture.md` §1) |
| Session manager | `agent-session-host` spec v0.3 | **ADAPT** | Contract, doorbell modes, park and supervision matrix are reusable; "extract as is" was dropped 2026-10-05 |
| Session manager | `ax` | **Ideas only** (launch-plan contract, canonical events, clone/teleport) | Not implemented; Ivan: "take only the most valuable ideas" (`DISCUSSION.ru.md` §2026-10-03 item 5) |
| Context manager: takeover / unified format | `parent/primary` takeover; park note `handoff_ref`; ax canonical events §13.14.1; the brief's handoff package | **ADAPT / new** | Not found as one module. The handoff package format is a wave-0 contract still to define (`ORCHESTRATOR-BRIEF.draft.md`) |
| Context bridge + in/out providers | `agent-session-bridge` design; ax plugin JSONL protocol as a template | **ADAPT** (spec needed) | Direction agreed; no plugin interface written |
| Trust gate | curator-trust + mandates | **REUSE** (design) | "No new trust library" (`ivans/wiki/decisions.md` 2026-10-05) |
| Goal provider (stdin injection) | Codex text directive (#480), doorbell `next_turn/steer`, self-issued goal writes | **ADAPT** | Matches "goals are stdin injection"; today tied to the board-goal ledger (`ivans/wiki/research/2026-10-01-unified-goals.md` §0, §1.2) |
| Keeper | curator-keeper spec | **ADAPT later** | Nothing implemented; `keeper up` and the registry are useful for the meta/product keeper |
| Board (later plugin) | task-board kernel + `curator-playbook` | **REUSE playbook as the flow config; REPLACE hard-coded flow** | Playbook already models types, nesting, lifecycle and role per state |
| Own runtime / Apiary | curator-agent-runtime | **Defer** | Spec only |

## 9. Conflicts and duplicates

1. **Three session holders.** `tb-sessiond` (live), `agent-session-host` (spec) and `ax` (spec, foundation code). `ax` explicitly does not replace `tb-sessiond` (SPEC §1.2), while the host spec plans `ax` as a long-term backend (§13). The architect's draft and the 2026-10-05 decision add a fourth shape: a new core plus a facade.
2. **Extraction strategy reversed.** "Extract as is, priority" (session-host §3, decided 2026-09-24) vs "new minimal core, hybrid (c)" (`ivans/wiki/decisions.md` 2026-10-05). The spec copy here (v0.3) does not reflect the change. The session-core study cites `agent-session-host` spec "Architecture v1" and `spec/hosted-launch-contract.md` (`research/2026-10-05-session-core-study.md` evidence table); these are **not found** in `ivans/agent-session-host/`.
3. **Two launch-plan types.** The board's `PrimarySessionLaunchPlan` (interactive/managed_host/managed_client) vs the ax launch-plan request (`architecture.md` §6.3).
4. **Goal medium.** Native goals (Claude `/goal`, the doc forbids downgrading to prompt-only, `claude-goal-runtime.md`:1–7) vs text/stdin directives (Codex #480; the owner's concept).
5. **Message delivery paths.** task-board notices (attached client only), waggle §10 doorbell+pull, host doorbell modes, and bridge producers all overlap. waggle §10 needs an amendment (session-host §7).
6. **"Keeper" means four things.** The curator-keeper main loop, the `tb-keeper` agent session, the owner's `X_keeper` product keeper, and the a2a meta-keeper.
7. **"Profile" is overloaded.** Curator profile, ax execution profile `standard|yolo` (launcher SPEC §3), codex `-p` layer, role profile. Runtime ids also differ (`claude` vs `claude_code`; session-host §12.1).
8. **Carrier.** The owner's example is Matrix, while the 2026-10-02 decision says "nothing binds to Matrix" and proposes XMPP first.
9. **HOME.** Owner: relocate HOME. Curator: relocate tool vars, keep HOME (Muse v3 explicitly). Remote workers: empty HOME.
10. **Interactive vs non-interactive.** Owner: one launcher for both. Curator decisions: no headless `curator run`; children stay in `task-board spawn` (0021 §6).
11. **CLI fronts.** `keeper`, `curator session`, `task-board session` and `ax` all name session operations.

## 10. Open questions

1. Does the owner's "session manager + context manager" map onto `agent-session-host` (supervisor/holder) + `agent-session-bridge`? Or is a separate context-manager module wanted between them? The wiki has no such split.
2. Should the launcher relocate `HOME` itself, or are Curator's tool-var homes plus credential passthrough enough? (Claude on macOS needs a per-home `/login`.)
3. Who owns non-interactive spawn without the board: a headless `curator run`, which current decisions reject, or a new spawn service over agents-management exec plans?
4. What is the bridge plugin interface: in-process Go interface or out-of-process JSONL (ax-style)? Long-lived subscriptions (Matrix) do not fit "one process per op".
5. Should goals be text-only for all harnesses (the owner) or native where admitted (the unified-goals recommendation)? Where does a board-free goal manager store goal state?
6. Is the latest `agent-session-host` spec (Architecture v1, hosted-launch contract) part of this inventory? The copy here is v0.3.
7. How do remote-harness agents attach to a project? Not found in `ivans/`; the remote-worker-harness lives on Alexey's side.
8. Carrier priority for the first provider: Matrix (existing a2a / collective mode) or XMPP (2026-10-02 direction)?
9. Which mandates spec backs grants? It is referenced but not present in `ivans/`.
10. Keeper scope: is curator-keeper's process registry the owner's "Space/product keeper", or something else?
