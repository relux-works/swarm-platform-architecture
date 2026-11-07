Product advice record — 2026-10-05 (Curator perspective; advice only).
    # Curator advice on the platform-rebuild vision (DRAFT, advice only)
    
    Advice from the curator orchestrator, not decisions. Pins: curator-spec `43bf0a2` (rc.14), curator main, curator-run `origin/main` (`fbcdbaf`), agents-management `origin/main` (`b30c3ef`). "env §" = curator-spec `protocol/environments.md`.
    
    ## 1. D1: HOME vs tool-home
    
    **Position:** agree with "tool-home by default". Drop `home_mode: full-home` as a Curator or manifest mode.
    
    **Evidence**
    - Curator never sets HOME for a launch. `HOME` MUST NOT appear in a fragment or be replaced (env §10.2, l.3243). Fragment names come only from the closed registry (env §10.3; `internal/envfragment/envfragment.go:347`). Muse hangs on a Keychain prompt when HOME is replaced (env §7.1, l.1311).
    - Credentials (env §7.4):
      - Claude on macOS: one Keychain item per `CLAUDE_CONFIG_DIR`. Nothing is linked (`internal/envregistry/envregistry.go:252`), `shared` is refused (`:450`), and each managed home needs its own `/login`.
      - Codex: `auth.json` file-link. The in-place writer is verified. Under keyring storage the credential is ambient.
      - Muse: `config/muse/auth.json` file-link. Refresh is unverified.
      - Pi: file-link to the agent root.
      - CIP-0003 proposes three Claude modes: `per-home`, `token` and `helper`.
    - Skills: a managed home gets only its profile's lock (env §9.4). User-level native skills do not reach it.
    
    **Gaps.** "Exactly the declared set" is not true today, and moving HOME would not fix any of these:
    - Skill commands are machine-current and unavailable in managed launches (env §9.4, l.2588).
    - Project-native discovery is driven by cwd: repo instructions, settings, hooks, `.agents/skills` and Codex project config (CIP-0002 §Current state).
    - Claude's strict-MCP flag is applied only when the profile's MCP set is non-empty (CIP-0002 E4).
    - Codex revision-A seeds inherit native MCP servers (env §7.4).
    - Muse loads foreign personal context (env §7.1).
    - Native settings and hooks are out of scope (Decision 0014 is still proposed).
    
    **Recommendation**
    - Treat CIP-0002 strict project-context mode as the real "exact set" mechanism.
    - Use CIP-0003 `token` mode for unattended Claude so it does not need a login per home.
    - Keep empty-HOME isolation as a sandbox property of the remote executor. It is not a profile or fragment field.
    
    ## 2. D2: headless ownership
    
    **What 0021 §6 says:** tracked non-interactive children stay with `task-board spawn` and its exec machinery, and there is no headless `curator run` (`decisions/0021…md:133-136`). Two rejected alternatives give the reasons:
    - 0019 rejected curator-run as the only launcher because exec machinery belongs to the process owner: process groups, abort fences, run manifests, exit classification, retries, worktrees and goal directives (`0019…md:151-158`).
    - 0021 rejected curator-run hosting sessions itself (`0021…md:208-212`).
    
    **Position:** amending §6 is reasonable, but only for *composition*. Do not move exec or holding into the launcher.
    
    **Recommendation:** keep one composer and one fragment reader, curator-run, and give it a compose-only output for a non-interactive mode. Today task-board is a second fragment consumer (0019). The holder (M1) or task-board receives the composed Decision 0013 §3.2 plan through the `ax start --launch-plan` contract that 0021 §2 already defines. The VISION §4.1 launcher CLI should be a thin client over this: it carries target, io_bindings, goal and policy, and it never reads a fragment or spells a flag. Reasons:
    - **Tracking:** ax/0021 hosting stays the single intake.
    - **Permission transport:** the 0018 rules for headless and tracked runs apply in one place. Silence resolves to `native`, and tracked `yolo` is refused until a versioned ax capability exists (launcher SPEC §4.6, l.848-872).
    - **Fragment trust:** the closed-schema reader rules and mutant harness are not duplicated.
    
    ## 3. Manifest → profile mapping (VISION §4.1)
    
    **Correct mappings**
    - `instructions` → context modules and system prompt (env §3, §5.5).
    - `skills` → lock skills (§9.4).
    - `mcp` → MCP declaration packages (§2.2).
    
    **Wrong or missing**
    - `tools` and `tails`: commands do not reach managed homes. They need CIP-0002 `command_environment` (fragment v4) and CIP-0004 (append PATH, never source files).
    - `permissions`: a profile can carry only `native|yolo` (0018). Richer rules belong to machine-owned configuration (CIP-0006, the narrow form of 0014), not package bytes.
    - `network_profile`, `home_mode`: these are not profile content. "A profile chooses what the context says, never how a process is launched" (env §10.3).
    - The remote bundle should be derived from `lock_sha256`, not maintained as a parallel format.
    
    **M2 adapters (Claude stream-json, Codex app-server)**
    - Fragment-level is ruled out by §10.3.
    - Pass-through after `--` works mechanically, because native args are forwarded verbatim (agents-management `pkg/agentic/system.go:108-125`).
    - In direct mode the child inherits the holder's stdio (curator-run `internal/execution/execution.go:111-120`).
    - The cost of pass-through: the run is classified headless (silence resolves to `native`), nothing about it is typed, and resume cannot reproduce it.
    - Tracked stdin is a one-shot payload of at most 64 KiB that is closed after the last byte (0013 §4). It cannot be a duplex channel.
    
    **Recommendation:** add a typed agents-management launch mode for hosted streams. It declares the transport per adapter (none of Exec, Interactive or ManagedSession fits). curator-run selects it with a flag, and an ax capability carries the duplex I/O.
    
    **Still missing at fragment level (v4):** `project_context`, `command_environment`, settings digest and MCP `policy` (CIP-0006), and an explicitly empty strict-MCP set.
    
    ## 4. D4: goals
    
    **No spec conflict as long as the goal stays in the session plane.**
    - The launcher refuses `--goal`, and the interactive plan carries no goal machinery (0013 §5; `system.go:120`). `LaunchRequest.goal` must therefore go to M3, never into argv.
    - Plan stdin cannot carry nudges (0013 §4).
    - Goal text must stay out of system-prompt and managed surfaces. Those are hashed (env §5.6), so writing it there would cause drift.
    - 0021 §4 already puts board goals and run notices in the host. D4 effectively answers 0021 open question 5 ("notices from other sources") and should be filed as that answer.
    
    **Risks**
    - A headless `native` session can stall on a permission prompt. The no-progress detector must tell "waiting on a permission" apart from "no progress".
    - An agent-set goal is agent-authored, not host-authored. Do not give it a higher trust verdict.
    - The native `/goal` flag belongs to the LaunchRequest, not to the profile or manifest (§10.3).
    
    ## 5. Overlap with the curator roadmap
    
    - **Gate A (M2):** VISION §5 "fold in the agents-infra launchers" is Gate A, which runs through 0019 (adopted). M6 is the infra exit, blocked by #105, and CIP-0006 is its narrow path. Reuse these; do not run a parallel migration.
    - **Fragments:** VISION §4.8 S6 targets v3. CIP-0002, CIP-0006 and CIP-0003 metadata all land in v4. Plan one coordinated v4 revision.
    - **Keeper (KP):** curator-keeper's registry and `up` (spec only) are S4. `keeper up` already launches through `curator run --profile`.
    - **Credentials:** CIP-0003 refuses `token`/`helper` for tracked or remote runs until the final executor does protected lookup itself. The remote target (M6) inherits that requirement.
    - **Decision 0014:** still proposed. Native settings and hooks stay out of scope until it, or CIP-0006, is adopted.
    
    ## Objections
    
    1. `full-home` contradicts env §10.2 and §7.1 (Muse).
    2. A manifest that is a "superset of the profile" breaks the §10.3 profile-influence boundary.
    3. "Restart replays the stored plan by hash" conflicts with resume fidelity. The profile pin must be re-resolved and compared, and drift refuses by default (0013 Decision 7; 0021 §7.3).
    4. Native "preserve" resume only works in the same managed home, because session state and the Claude login are per home (env §7.4 isolation matrix, l.1710). Takeover across profiles has to "rebuild".
    5. A handoff package needs `lock_sha256` and the fragment digest, not only `manifest_ref`. It must never hold token-mode secrets.
    
    ## Open questions for them
    
    1. Is a local full HOME needed for anything that CIP-0002 strict mode plus tool-homes would leave uncovered? Please name the specific leak.
    2. For headless M2 sessions: should permissions be `native` with prompts surfaced through M3, or wait for the versioned ax `yolo` capability?
    3. Will M1 take its intake through the `ax start --launch-plan` contract, so curator-run hands off unchanged?
    4. Remote: should the target host resolve Curator locally from a launch intent (our preference), or receive a rendered bundle?
    5. For unattended Claude keepers and workers: one login per managed home, or CIP-0003 `token`?
