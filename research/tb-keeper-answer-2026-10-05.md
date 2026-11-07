Product advice record — 2026-10-05 (task-board perspective; factual, not canonical).
    tb-keeper, short answers from Ivan's side. Factual, not canon.
    (1) Missing from the inventory:
    - curator-model-router (cmr): model and effort routing per task class and difficulty, in shadow this week (tb-R195).
    - curator-network-profiles: network/egress profiles and the adapter-conformance probe. It is public, v0.3.0 shipped today.
    - curator-inference-manager: local model serving.
    - curator-skill-registry, plus relux-agents-infra (the agents-infra claude/codex launchers, MCP composition, skills and instructions into ~/.agents).
    - curator-run, the provider-run shim (v0.2.0), and the env/harness release registry (proposed; herdr study).
    - task-board's validation FIFO and provider-limits (machine-wide suite semaphore, rate limits). It belongs in the platform even with the board excluded.
    - runner-control (self-hosted CI runner control), and the host-hygiene and reboot-restore bridges (mini-sessions / ivmbp-sessions).
    - agent-session-manager-spec (ax SPEC, v0.7.0).
    - wiki.
    (2) Canonical today: tb-sessiond. It is the only one in production, as task-board's internal/sessionmanager. agent-session-host is the spec and the TARGET module for extracting tb-sessiond: a hybrid built in a private fork (tb-R188), with no code extracted until both founders finish the architecture review (tb-R191). Architecture v1 is in agent-session-host#11. ax (agent-session-manager) is a separate local-first, cross-host session orchestrator built from its own SPEC; its implementation is early (contracts and storage, no session behaviour yet). In session-host's spec ax appears as a later pluggable terminal backend (pty / tmux / ax) and as the model for the out-of-process provider plugin protocol. So: tb-sessiond is live, agent-session-host is the destination, and ax is an optional backend and protocol peer.
    (3) Interaction schemes in relux-works/wiki main:
    - research/2026-10-05-session-core-study.md (hapi, buzz, Reef);
    - research/herdr/network-profiles.md;
    - research/2026-10-05-open-session-protocol-landscape.md (OpenClaw+Reef, herdr, ACP, A2A, MCP, harness session APIs, with an adopt/align/diverge table);
    - research/goal-host-plane-synthesis.md, research/keeper-and-process-lifecycle.md, research/agent-loop.md;
    - the book chapter on launch and session-host (book/ru/07) and waggle (book/ru/11).
    For diagrams: agent-session-host#11 (module map, signed ingress, controlled restart, preserve vs rebuild) and agent-session-bridge#1 (architecture and threat model).
    A suggestion: Alexis's design and Ivan's R191 package cover the same layer (session holder, context bridge with in/out providers, launcher, trust via mandates). Bring both to the same architecture review, rather than run two parallel designs.
