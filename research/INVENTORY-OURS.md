# Inventory of `ours/` against the owner's platform concept

Scope: the five repos under `ours/` (docs-only copies). The concept is in `00-owner-concept.md`. Every claim cites a path relative to the
workspace root. "Not found" means that no doc in `ours/` states it. Code is not in the copy, so behaviour comes from the docs.

## 1. Summary table

| Component | Purpose | State | Concept role it fills |
| --- | --- | --- | --- |
| a2a-swarm (`a2a` CLI + protocol) | Agent-to-agent messaging over a local Matrix homeserver: rooms per project, threads as topics, cards, subscriptions, a durable mailbox, and a hook doorbell | **In production use** | Partial **context bridge** (a Matrix in-provider with pull delivery), partial **session holding** (identity lease), **trust** (untrusted-data frame) |
| remote-worker-harness (`rwh`) | Runs Codex, Claude or Muse on the Mac mini's subscriptions while every tool call runs locally (jailed) | **In production use** (modes 1, 2b, 2c, 2d and 3 are live-accepted; standing workers run under launchd) | **Remote harness**; part of a **launcher** (remote HOME relocation, a bundle as a manifest); a small Matrix in/out loop (`rwh worker`) |
| worker-jail | Security protocol and reference jail: one hardened container per tool call in a no-mount colima VM; changes leave only as patches | **v1.1 implemented and used by rwh's standing workers**; v2 is design only | **Trust / isolation** under the remote harness |
| mandates (`mandate` CLI) | Owner-signed single-use grants (power-of-attorney envelopes) that are verified offline, with a git registry | **Prototype**: the CLI is implemented and runs end to end with test keys; there is no real key yet | **Trust** (authorising privileged launcher/identity steps) |
| skill-agents-management (`agents-management` module + CLI; the installed agents-infra copy in `.agents/`) | The spawn plane extracted from task-board: runtime registry (system × vendor), launch plans, limits and availability. agents-infra composes and prepares provider launches and installs skills, instructions and configs | **Module published (v0.4.3) and consumed by task-board**; the CLI is read-only and its plugin lists are empty | Core of a **launcher** (a launch-plan value, project-local skills/instructions); no process ownership |

## 2. Per-component detail

### 2.1 a2a-swarm

| Aspect | Finding | Source |
| --- | --- | --- |
| Purpose | Coordination for a swarm of Claude Code and Codex orchestrators. It is "deliberately not part of any task board" | `ours/a2a-swarm/README.md` (intro) |
| State | Live. Matrix (tuwunel, a local Matrix homeserver) is the transport since 2026-09-29; the git topics are a frozen archive. The projector runs under launchd. Live rooms are archived with `a2a archive` | `ours/a2a-swarm/docs/protocol.md` rule 1; `ours/a2a-swarm/archive/a2a-swarm/plan.md:61`; `ours/a2a-swarm/AGENTS.md` |
| Model | Service → rooms (one per project) → topics (threads). Agents are global, with one card each. Product spaces use `#X-lobby`, `#X-broadcast`, `#X-system`; `#system` is a projection room | `ours/a2a-swarm/docs/protocol.md` rules 0, 24, 28; `00-owner-concept.md` (layout) |
| CLI | `host init`, `identity ensure/release`, `register`, `room new`, `join/leave/invite`, `topic new`, `post`, `read`, `attach/fetch/files/pin`, `archive`, `wait`, `watch`, `inbox`, `ack`, `hook session-start/prompt/stop`, `hook install/uninstall/pause/resume`, `subscribe/unsubscribe/subs`, `sub-request/sub-accept`, `project`, `card set/get`, `status set/get`, `skill install`, `mute/follow`, `subs sync` | `ours/a2a-swarm/docs/cli.md` (headings 43–720) |
| Files | `~/.config/a2a-swarm/{matrix.env,host,agents/<name>.json,state/<name>.json,state/<name>.mailbox.jsonl}`, all 0600 | `ours/a2a-swarm/docs/cli.md` "Configuration and identity" |
| Identity | `<host>_<project>_<role>`. One live session holds an identity at a time through a 10-minute lease keyed by the hook's `session_id`, `A2A_SESSION_ID`, or `pid@host` | `ours/a2a-swarm/docs/cli.md` "One live session per identity: the lease"; `docs/protocol.md` rule 26 |
| Delivery | At-least-once durable mailbox: persist before the cursor advances; receipts only by `inbox` or `ack`; gaps are surfaced | `ours/a2a-swarm/docs/cli.md` "Delivery contract" |
| How it runs | A per-invocation CLI. The background `a2a wait --timeout 0` runs per identity (idle wake). Hooks run inside Claude Code or Codex. `a2a project` runs under launchd. The homeserver runs in Docker under colima on Alexis's Mac (a move to the Mac mini was proposed) | `docs/protocol.md` rule 4; `docs/cli.md` `a2a project`; `ours/a2a-swarm/archive/a2a-swarm/matrix-on-dedicated-mac.md:14,19` |
| tmux | `a2a bridge tmux` was **removed** on 2026-09-29: typing into a terminal could answer a permission or plan dialog | `docs/cli.md` "`a2a bridge tmux` (removed)"; `ours/a2a-swarm/research/waking-sessions-converged.md` §2.2 |
| Depends on | Go 1.25, a Matrix homeserver (needs `TUWUNEL_CLIENT_SYNC_TIMEOUT_MIN=0`), tuitestkit for tests | `ours/a2a-swarm/go.mod`; `docs/cli.md` (server requirement) |
| Governance | 32 protocol rules: advice process, redlines, blocking/non-blocking asks, impact notices, `RULINGS.md` | `ours/a2a-swarm/docs/protocol.md`; `ours/a2a-swarm/RULINGS.md` |
| Skill | The embedded `a2a` skill is installed into `~/.agents/skills/a2a` and linked into `~/.claude/skills` and `~/.codex/skills` | `docs/cli.md` "`a2a skill install`" |

### 2.2 remote-worker-harness (rwh)

| Mode | What | State | Source |
| --- | --- | --- | --- |
| 1 exec | `rwh codex-exec` / `rwh-codex`: a drop-in for one-shot `codex exec` on the Mac mini | implemented; used by semantic-cores | `ours/remote-worker-harness/README.md` (Modes, Mode 1) |
| 2 session | `rwh session`: one turn of a remote `codex app-server`; the 4 tools (`bash`, `read_file`, `write_file`, `apply_patch`) run locally | Codex v0 implemented | `README.md`; `docs/session-mode.md` |
| 2b Claude | headless `claude -p` on the Mac mini with only `mcp__rwh__*` tools, served over an `ssh -R` unix socket | live-accepted 2026-09-29 | `docs/claude-mode.md` |
| 2c Muse | one sandboxed `muse-bin exec` per turn, with tools through a relay | live-accepted 2026-09-29 | `docs/muse-mode.md` |
| 2d run | `rwh run --bundle DIR --out DIR ...`: a bundle goes in; a patch, `report.json` and `calls.jsonl` come out | live-accepted 2026-09-29 | `docs/run-mode.md` |
| 3 worker | `rwh worker`: a multi-turn session with its own a2a identity; addressed messages become turns and the answers are posted back | live for Codex, Claude, Muse (`rwh-codex-rwh`, `rwh-claude-rwh`, `rwh-muse-rwh`) | `docs/worker-mode.md` (Deployment table) |
| mandate-run | `rwh mandate-run a2a-identity-ensure`: a privileged step only under a valid mandate | implemented, tested with fakes and the real CLI in a test store | `docs/mandate-run.md` |

| Aspect | Finding | Source |
| --- | --- | --- |
| How it runs | Local `rwh` process. ssh to the alias `relux-works-dedicated-macmini` (`RWH_HOST`): `ssh -L` to a private unix socket for Codex, `ssh -R` for the Claude and Muse MCP. Standing workers run as per-user launchd agents (`works.relux.rwh.<name>.plist`, KeepAlive on failure) | `docs/session-mode.md` (env table, ssh steps); `docs/worker-mode.md` "Deployment" |
| Remote "HOME relocation" | Codex: a per-session scratch `CODEX_HOME` (`/tmp/rwh-session/<id>/home`) with `features.goals=false`. The docs disagree on auth: the README and the diagram at `session-mode.md:86` symlink `~/.codex/auth.json`, while the auth-owner section says "the tenant home has no `auth.json`" and the single refresher `internal/authowner` supplies access tokens (`session-mode.md:198-222`). Claude: scratch `CLAUDE_CONFIG_DIR`, with `CLAUDE_CODE_OAUTH_TOKEN` read from rwh's own keychain through `rwh-secret`. Muse: a login copy in a scratch dir | `ours/remote-worker-harness/README.md` (Mode 2, auth owner row); `docs/session-mode.md:86,198-222`; `docs/claude-mode.md`; `docs/muse-mode.md` |
| Bundle = manifest | `bundle.json` v1 has `id`, `role`, `task`, `goals[]`, `skills[{name,text}]` (inlined), `workspace{repo,ref}` and `answers[]` | `docs/run-mode.md` "Bundle" |
| Questions | The model writes `RWH-QUESTIONS.json`. A blocking question gives `needs_input`, exit 75. rwh keeps no state between runs | `docs/run-mode.md` "Execution" step 3–4 |
| Worker guards | allow-from, a daily token budget (cached input counted), rate, ping-pong cap, context cap (`--max-turn-input`), turn timeout, lifetime. No implicit defaults | `docs/worker-mode.md` "Guards", "Settings"; `deploy/rwh-codex-rwh.md` |
| Memory | "No context is carried across restarts (v1)"; a thread rotates at the context cap | `docs/worker-mode.md` "Memory" |
| Isolation | Built-in tools are kept off on the remote side by layers (tool surface, containment, tripwire, audit). Local tools run under Seatbelt or the worker-jail backend | `README.md` (Mode 2 table); `docs/claude-mode.md` "Keeping built-ins away"; `docs/worker-mode.md` "Tool backend" |
| Depends on | `github.com/relux-works/worker-jail`, ssh, remote `codex` / `claude` / `muse-bin`, the a2a binary (`RWH_A2A`) for worker mode, colima `workers` for `--jail`, the `mandate` CLI for mandate-run | `ours/remote-worker-harness/go.mod`; `docs/worker-mode.md`; `docs/mandate-run.md` |

### 2.3 worker-jail

| Aspect | Finding | Source |
| --- | --- | --- |
| Purpose | Assume the worker is hostile. Each tool call runs in a fresh hardened container (`--network none`, cap-drop ALL, uid 10001, read-only rootfs, limits) inside the colima VM `workers` started with `--mount none` | `ours/worker-jail/README.md`; `docs/protocol.md` §1, §3 |
| Interface | Go package `jail` plus the `worker-jail` CLI: `doctor`, `provision`, `run`, `export`, `apply [--write-scope]`, `deprovision`, `seed-cache`, `seed-gomod`, `usage`, `ls`, `kill`, `purge` | `docs/protocol.md` §6; `README.md` Tools |
| Data flow | In: a git bundle of a landed base ref, cache seeds, argv/stdin. Out: stdout/stderr/exit and a patch. Applied only after review, with hooks disabled | `docs/protocol.md` §3, §8, §10 |
| State | v1.1 normative; red-team **PASS** at `c29ab55`; used by the live rwh workers. v2 (per-worker policy, egress service, dirty-worktree seeding) is design only ("implementation waits") | `docs/redteam-report.md`; `docs/decisions/2026-09-29-v2-direction.md` D3; `docs/design/v2/README.md` |
| How it runs | A library called by rwh. Docker endpoint pinned to `unix://$HOME/.colima/workers/docker.sock`. Host state in `~/.local/state/worker-jail/`. No sudo | `docs/protocol.md` §6, §11 |
| Depends on | Go stdlib, docker CLI, colima, git | `README.md` Tools; `ours/worker-jail/go.mod` |

### 2.4 mandates

| Aspect | Finding | Source |
| --- | --- | --- |
| Purpose | Fixes "relay forgery": the owner signs one exact action for one agent on one host with a presence-gated key (Touch ID via mac-keyvault), and the consumer verifies it offline | `ours/mandates/docs/SPEC.md` §1; `ours/mandates/README.md` |
| CLI | `mandate issue/verify/consume/report/revoke/revoke-key/revoker/successor/issuer/pin/state/source/config/host/registry sync/q/version`; JSON on stdout; exit codes 10–26 per verdict | `README.md` "Commands" |
| Files | `mandates.json` manifest (sources, expected issuers); consumer state under the passwd home; git registry sources | `README.md` "Where things live"; `SPEC.md` §11 |
| State | The CLI implements §12.1 and the full §9 verification; the §17 walkthrough runs with test keys. The first real mandate waits for a mac-keyvault build with Secure Enclave and user presence. `SPEC.md`'s header still says "Nothing here is implemented yet", which is stale against the README | `README.md` "Status"; `SPEC.md` line 3 |
| Trust limit | Same-uid agents are "honest-but-mistaken peers". The host key proves place, not agent | `SPEC.md` §3 |
| Consumer | `rwh mandate-run`, for one action: `a2a-identity-ensure` | `ours/remote-worker-harness/docs/mandate-run.md` |
| Depends on | Go stdlib, git, mac-keyvault (real keys) | `README.md` "Install and build" |

### 2.5 skill-agents-management (+ agents-infra copy)

| Aspect | Finding | Source |
| --- | --- | --- |
| Purpose | The spawn plane extracted from task-board: "this tool knows how to run agents; the board knows what they should work on" | `ours/skill-agents-management/README.md` "Why", "What the tool deliberately does not do" |
| Abstractions | Generic plugin graph `Declaration{ID, Kind, Dependencies}`; `agentic.System` (7 systems: codex, claude, qwen, gemini, muse, agy, pi) with `Capabilities` incl. `HomeEnvVar`/`DefaultHome`; `vendorplugin` (anthropic, openai, alibaba, google, local-models); runtimes = system × vendor; `BuildLaunch` → `Plan{Binary, Argv, Env, Stdin, WorkDir, Home}`; `BuildMultiNodePlan`; `providerlimits` availability | `README.md` "Architecture"; `docs/architecture.md` "Runtimes", "`BuildLaunch`", "Typed multi-node launch plans" |
| Boundary | It "ends at a VALUE": a consumer turns the plan into a process. Exec, process-starting preflights and Claude goal preparation stay in task-board | `docs/architecture.md` "Boundaries with task-board" |
| CLI | `agents-management version / plugins / vendors / runtimes / local-runtime status`. `plugins` and `vendors` print an empty list in the shipped binary | `README.md` "Current CLI surface" |
| State | v0.4.3 published; v0.5.0 candidate (mlx engine metadata). task-board consumes it (`STORY-260823-1sxcmg`, integrated at `b34aa20`) | `docs/shipped-state.md` §"Current published release"; `docs/architecture.md` "Extraction plan" step 4 |
| Goals | The claude plugin's goal mode uses native `/goal <predicate>` with no stdin; goal preparation stays in the consumer | `README.md` "The claude plugin" |
| agents-infra (installed copy; source repo `relux-agents-infra` is outside this workspace) | `agents-infra setup global/local`, `doctor`, `prepare`, `compose [--mode primary-session]`, `codex/claude/pi` launchers. It syncs `.instructions/`, `.skills/`, `.configs/` into `.agents` and links them into `.claude/` and `.codex/`. Project MCP opt-in via `.agents/.configs/project-config.toml` | `ours/skill-agents-management/.agents/README.md` (Quick Start, "Primary-session project preparation contract", "Project-Local MCP Opt-In"); `.agents/.agents-infra-install.json` |
| Session manager link | "The primary launch path for a board-scoped session is the Task-board Session Manager": `task-board codex/claude` call `compose` + `prepare`, then own the process and the native board-goal binding | `.agents/README.md` "Task-board Session Manager wrappers" |
| HOME isolation | Pi only: isolated `PI_CODING_AGENT_DIR` and session state. For Codex/Claude primary sessions, no HOME/`CODEX_HOME`/`CLAUDE_CONFIG_DIR` relocation was found in `ours/skill-agents-management` | `.agents/README.md:343,600`; grep for `CODEX_HOME`/`CLAUDE_CONFIG_DIR` matches only `LOGBOOK.md` there |
| Depends on | Go 1.25.5, cobra, go-toml | `ours/skill-agents-management/go.mod` |

## 3. Mapping onto the concept's modules

| Concept module (`00-owner-concept.md`) | What exists in `ours/` | Coverage |
| --- | --- | --- |
| Session manager (hold sessions, takeover) | a2a identity lease (one live session per identity; `identity release --force` for takeover of the *identity*, not the context) (`a2a-swarm/docs/cli.md`); rwh worker holds a remote session up to `--lifetime` and reopens on failure (`remote-worker-harness/docs/worker-mode.md`). The "Task-board Session Manager" and tb-sessiond live outside `ours/` (`.agents/README.md`; `a2a-swarm/research/waking-sessions-converged.md` §1) | **Gap** in `ours/`; only fragments |
| Context manager: restore / unified format / transfer | Not found. rwh: "No context is carried across restarts" (`worker-mode.md`); `rwh run` carries no state between runs (`run-mode.md`) | **Gap** |
| Context manager: stdin/stdout wrapping | rwh already owns the I/O of remote agents: stream-json turns for Claude, app-server JSON-RPC for Codex, `exec --json` for Muse (`claude-mode.md`, `session-mode.md`, `muse-mode.md`). Nothing local wraps a local Claude/Codex session's stdin; the target "session host" with native adapters is a proposal (`waking-sessions-converged.md` §3 Target) | **Partial** (remote only) |
| Context bridge, plugin interface | No provider plugin interface found. agents-management's opaque-kind plugin graph is the only generic plugin registry (`README.md` "General graph") | **Gap** (registry pattern reusable) |
| In/out provider: Matrix | a2a (in: `wait`/`watch`/`inbox`; out: `post`). `rwh worker` is a working Matrix in→turn, answer→out loop for remote agents (`worker-mode.md`) | **Partial, pull-based** |
| Goal provider / Ralph loop | Not found as a component. Native goals are switched off for Codex in rwh (`features.goals=false`, `exec-mode.md:40`); `bundle.goals[]` is prompt text (`run-mode.md`); protocol rule 32 forbids goal continuation while only parked work remains (`docs/protocol.md`) | **Gap** |
| Launcher: HOME relocation keeping auth | Done for **remote** agents by rwh (scratch `CODEX_HOME` + authowner tokens; scratch `CLAUDE_CONFIG_DIR` + keychain token). Locally only Pi (`.agents/README.md`) | **Partial** |
| Launcher: manifest-declared skills/tools/instructions | agents-infra project-local `.agents/` (skills, instructions, MCP opt-in) + `compose`/`prepare`; rwh bundle `skills[]`/`role`/`goals`; rwh's 4 tools fixed | **Partial**; no single manifest format |
| Launcher: interactive and non-interactive spawn | agents-management `LaunchMode` plans; agents-infra `launch_variants.interactive` / `managed_host` (`.agents/README.md`); rwh is non-interactive only | **Partial** (plans, not process owner) |
| Remote harness | rwh (all modes) + worker-jail | **Filled** |
| Board / flows | Not in `ours/` (task-board lives in skill-project-management, outside scope). Protocol notes task-board has no priority/label field (`docs/protocol.md` rule 28.4) | **Out of scope / gap** |
| Trust | mandates (owner grants), worker-jail (containment), a2a content boundary + lease + human-only accounts (`docs/cli.md` "Identity safety"), rwh no-implicit-defaults | **Partial, strong pieces** |

## 4. Overlaps

| Overlap | Where | Note |
| --- | --- | --- |
| Launch planning in two places | agents-management `BuildLaunch`/`Plan` vs agents-infra `compose --mode primary-session` | Both emit non-launching plans; agents-infra is for primary sessions, agents-management for spawned children (`docs/architecture.md`; `.agents/README.md`) |
| Provider launch knowledge in three places | agents-management `pkg/agentic/systems/{claude,codex,muse}`, rwh's own Claude/Codex/Muse drivers, agents-infra launchers | rwh builds its own argv (e.g. `claude -p --restricted --tools ""`), not via agents-management (`claude-mode.md`) |
| Delivery / mailbox | a2a mailbox vs proposed session host vs tb-sessiond notice queue | Ownership was settled as "a2a owns the interim mailbox" (`waking-sessions-converged.md` §2.5) |
| Remote workers in chat | Protocol rule 25 says remote workers are NOT in the chat and know nothing about a2a; `rwh worker` has its own a2a identity and card and posts | `docs/protocol.md` rule 25 vs `worker-mode.md` (live table) |
| Identity onboarding | `a2a identity ensure` vs `rwh mandate-run a2a-identity-ensure` (which passes `--product`/`--preset`, flags not in `docs/cli.md`) | `mandate-run.md`; `a2a-swarm/docs/cli.md` |

## 5. Gaps against the concept

1. **Session manager**: not in `ours/`. There is no session registry, keep-alive, attach/detach or takeover of a running context.
2. **Unified context format and transfer** (takeover, partial context to a spawned agent): not found.
3. **Context bridge plugin API** (abstract in/out provider interface, several providers per session, provider config handed to a spawned agent, e.g. a Matrix channel): not found.
4. **Goal provider** (set/clear own goal, nudging via stdin): not found; only text goals in bundles and native `/goal` in the claude plugin.
5. **Local HOME relocation** for Claude/Codex with a manifest of skills/tools/instructions: not found; agents-infra writes into the project's `.claude/`/`.codex/` instead.
6. **One launcher**: no single component that launches local interactive, local non-interactive and remote-harness agents through one interface.
7. **Project attachment of remotes**: done per worker by flags/plist (`--project`, `--jail-project`, `--room`, `--allow-from`) and a2a room membership (`worker-mode.md`; `deploy/rwh-codex-rwh.md`); no declarative binding.
8. **Board as plugin with configurable flows**: not in `ours/`.
9. **`docs/products.md`** (products spec cited by protocol rule 27): not found in `ours/a2a-swarm/docs/`.

## 6. a2a "doorbell + inbox + hooks" vs the concept's stdin-injecting in/out providers

| Dimension | a2a today | Concept |
| --- | --- | --- |
| Direction in | **Pull**: hooks (`SessionStart`, `UserPromptSubmit`, `Stop`) only ring with a fixed ≤300-char template; the agent runs `a2a inbox` and gets bodies as **tool output** inside an `UNTRUSTED PEER EVENTS` frame (`docs/cli.md` "Environment delivery", "`a2a inbox`") | **Push**: the provider translates channel messages into the agent's **stdin** |
| Direction out | The agent calls `a2a post` explicitly; nothing reads its stdout | The out provider handles the agent's output and sends it to the channel |
| Idle wake | One background `a2a wait --timeout 0` per identity; hooks fire only on session activity (`docs/protocol.md` rule 4) | The wrapper owns stdin, so it can wake an idle agent directly |
| Authority | Deliberate: hook output has near-user authority, so peer text never enters it (`docs/cli.md`; `waking-sessions-converged.md` "Content boundary") | stdin injection = user-turn authority, unless the wrapper frames it |
| Terminal typing | Retired (`a2a bridge tmux` removed) because typing can hit dialogs (`docs/cli.md`) | stdin wrapping of a process owned by the launcher avoids the TTY race, but only if the wrapper knows the turn state |
| Plugin model | One built-in transport (Matrix); subscriptions are selectors in account data (`docs/protocol.md` rule 10) | Many providers (Matrix, goal, board…) behind one interface |
| Durability | At-least-once mailbox with receipts and gaps (`docs/cli.md` "Delivery contract") | Not specified |

Reading: a2a's mailbox and subscriptions already form a solid **Matrix in-provider back end**. The concept's wrapper is close to the "session host + native adapter" target in `waking-sessions-converged.md` §3 (mailbox → session host → Claude channel/stream-input or Codex `turn/start.toolOutput`). That target keeps peer content out of user-authority input. The concept's "goals as stdin injection" conflicts with that content boundary unless injected text is host-authored (a goal nudge) or framed as data. `rwh worker` shows a push variant already: an admitted message becomes a whole turn and the answer is posted out (`worker-mode.md`).

## 7. `rwh run` / `rwh worker` vs "the launcher can launch a remote-harness agent"

| Launcher concern | rwh today | Source |
| --- | --- | --- |
| Entry point | `rwh run` (one non-interactive turn, bundle in → patch/report out); `rwh worker` (standing, multi-turn, Matrix-driven); `rwh session` (one turn, prompt in) | `run-mode.md`; `worker-mode.md`; `README.md` |
| Manifest | `bundle.json`: role, task, goals, inlined skills, workspace, answers; tools fixed to 4 | `run-mode.md` "Bundle" |
| HOME / auth | Remote scratch homes with auth injected without copying refresh tokens to tenants | `session-mode.md`; `claude-mode.md` |
| Settings | All explicit; missing → exit 64 | `run-mode.md` "Invocation"; `worker-mode.md` "Settings" |
| Isolation | `--backend seatbelt|jail`; jail requires a landed clean ref until worker-jail v2 | `run-mode.md` |
| Questions loop | `needs_input` exit 75 + `report.json questions[]`; the orchestrator re-runs with `answers` | `run-mode.md`; `docs/protocol.md` rule 32.3 |
| Context in/out | None across runs; the worker keeps a thread only while its session lives | `run-mode.md`; `worker-mode.md` "Memory" |
| I/O providers | Worker mode hardwires a2a as its only in/out; `run` has none | `worker-mode.md` |

Reading: `rwh run` is in effect a **remote launch adapter** with its own manifest (the bundle). A unified launcher could call it as the "remote" target. Missing pieces: a shared manifest with local launches (agents-infra skills/instructions vs bundle-inlined skills), interactive/attachable remote sessions, context hand-off into the remote session, and pluggable in/out providers (worker mode hardwires a2a). rwh's drivers do not use agents-management plans (`claude-mode.md`), so remote and local launch knowledge are separate today.

## 8. Open questions

1. Should the session manager be built from the a2a lease plus rwh's session handling, or adopt the out-of-scope `agent-session-host` / `agent-session-manager` work referenced in `waking-sessions-converged.md` §2.5 (directories under `ivans/`, not inventoried here)?
2. Is stdin injection of **peer** content acceptable, given the content boundary the swarm adopted (`waking-sessions-converged.md` §3 Rules)? Or are only host-authored doorbells and goal nudges injected, with bodies still pulled?
3. How does a stdin wrapper detect turn state (busy, dialog open) without the hazard that retired `bridge tmux`?
4. Which manifest format becomes canonical: agents-infra `.agents/` + `project-config.toml`, or the rwh `bundle.json` shape?
5. Should local Claude/Codex launches get a relocated HOME (as rwh does remotely), or keep project-local `.claude/`/`.codex/` rendering (agents-infra)? How do `authowner`-style single refreshers apply locally?
6. Does protocol rule 25 (remote workers not in chat) supersede `rwh worker`'s a2a identities, or is the rule out of date?
7. How is a remote attached to a project declaratively? Today it is plist flags, a2a rooms and `--jail-project` (`deploy/rwh-codex-rwh.md`).
8. Should launcher-level privileged steps (identity, HOME/auth changes) go through mandates? mandates is blocked on mac-keyvault (`mandates/README.md` "Status").
9. Should the provider plugin interface reuse agents-management's opaque-kind plugin graph (`README.md` "General graph"), or be a separate runtime registry?
10. What is the goal provider's source of truth without a board, and how does it interact with rule 32's "no goal continuation while only parked work remains"?
