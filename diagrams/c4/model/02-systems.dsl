platform = softwareSystem "Swarm Platform" "Holds agent sessions, wraps their I/O, launches local and remote agents" {

  launcher = container "Launcher (thin client)" "Launch transaction: prepare, capacity, compose, compare expect_pin, admit, start, initialize, ready, with compensation. Never reads a fragment or store content, spells a flag, execs or holds" "curator run (canonical) / swarm launch (optional wrapper)"

  composer = container "Composer" "The only composer and fragment reader: resolves the role profile, builds one Decision 0013 plan (interactive, headless, hosted-stream with session-start permission frames); compose-only and compare-only answers" "curator-run + agents-management (one construction site)"

  sessionHost = container "Session Host (M1 + M2)" "One codebase: supervisor, minimal execution holders, host-enforced admission and fences, Context Engine package, goal ledger, host-owned journal" "agent-session-host (Phase-0 baseline: tb-sessiond)" {
    supervisor = component "Supervisor (M1)" "Plan intake (ax start --launch-plan contract, strict mode), session/execution registry, controller epochs, restart, resume, takeover, reconciliation, protected credential lookup at exec" "Go"
    admission = component "Admission and Fences" "admit() at every typed mutation; persisted admission fence open/closed/update_lock; durable idempotent enqueue (ack after fsync)" "Go"
    holder = component "Execution Holder" "One per execution: native process, PTY or framed pipes, exclusive input lease; no goal, board, carrier or journal semantics" "Go process"
    contextEngine = component "Context Engine (M2)" "Dispatcher (the only stdin writer), delivery evidence, interactions, export/seed of swarm-handoff/2, resolve_ref, egress projections" "Go package"
    adapters = component "Harness Adapters" "claude-stream-json, codex-app-server, muse-serve (hosted-stream/1), pty-preserve; readiness grammar pinned per release; unknown parks" "Go package"
    goalLedger = component "Goal Ledger" "Board-free goals (CAS, caller-derived author, budgets) and delivery records for board goal revisions" "Go package"
    journal = component "Host Store" "Journal, durable inbox, fences, plans, protected source storage (transcripts, tool outputs, patches)" "Files, append-only, owner-only" {
      tags "Store"
    }
  }

  harness = container "Agent Harness Session" "Claude Code, Codex, Muse or Pi process in a Curator managed tool home (HOME kept)" "Native CLI" {
    tags "Harness"
  }

  bridge = container "Bridge (M3)" "Hosts provider processes; trust gate; durable bridge-local admission; host enqueue; audience-checked outbox; tails" "agent-session-bridge" {
    bridgeCore = component "Bridge Core" "Binds providers to sessions with host-assigned handles, derives principals, enqueues to the host, staged receipts, egress projections" "Go"
    trustGate = component "Trust Gate" "Exact-byte signature, enrolled identity, grant scope for action and target, freshness, replay and id claims, binding revision; verdicts authoritative, host_authored, agent_authored, data, quarantine, reject" "Go"
    bridgeStore = component "Bridge Store" "Id claims, admission records, doorbell mailbox, outbox, audit log" "Files, append-only" {
      tags "Store"
    }
    pluginApi = component "Plugin ABI" "swarm-plugin/1: pinned executables, handles, secret broker, limits, restart recovery" "JSONL over stdio"
    decisionGuard = component "Decision Guard" "A small local model compares an admitted message with the addressee's grant specification and known injection patterns before the doorbell; the verdict is logged with a fingerprint and attached to the mailbox record" "local model"
    mailbox = component "Mailbox" "Held bodies with their verification records, fetched by the agent through its tool (inbox read); In and Out" "Files, append-only" {
      tags "Store"
    }
    tails = component "Tails CLI" "swarm-tail goal and park (no mandate); post and inbox read (binding grant; post rate-limited and audited); session token = same-UID guardrail" "CLI"
    matrixProvider = component "Matrix Provider" "Subscribes to rooms and threads, persists before advancing the cursor, emits envelopes, posts projected output" "Child process over a2a" {
      tags "Plugin"
    }
    goalProvider = component "Goal Provider" "Scheduler only: nudges for active goals through host enqueue; no goal truth" "Child process" {
      tags "Plugin"
    }
    terminalProvider = component "Terminal Watch" "Watch-only output projection; raw input goes through the holder lease" "Child process" {
      tags "Plugin"
    }
  }

  trust = container "Trust" "curator-trust + mandates: exact-byte verification, grants with attenuation-only delegation, revocation snapshots, capability tokens; assurance mode T today, mode S through OS-user isolation (v1.3)" "mandate CLI + library"

  remoteHarness = container "Remote Executor" "Runs a harness on another host from a pin-carrying launch intent; tools run in the remote workplace on this host; returns the accepted pin and plan digest" "rwh"

  remoteWorkplace = container "Remote Workplace" "One OS user on this host for a remote harness: SSH by the pinned key, tool calls run inside the user boundary, kernel firewall per UID; the component name is pending the owner's decision" "OS user + rwh"

  dispatcher = container "Launch Dispatcher" "Optional module: run accounting (ids, status, wait, cancel, reconcile after a crash), local host capacity, OS-user lifecycle through one privileged helper; checks the spawn grant (attenuation only); the board's spawn calls it; without it the orchestrator calls the launcher directly" "Go daemon"

  keyKeeper = container "Key Keeper" "Master secret in hardware-backed storage; hierarchical key derivation per agent identity (never per OS path); signs and decrypts on request over a local socket, identifying the caller by peer UID; publishes the root and descendant signatures; never releases a private key" "privileged daemon"

  credentialBroker = container "Credential Broker" "Holds long-lived provider logins; hands each launch what its harness consumes (one-year token in env, API key through the helper command, shared file); tracks expiry; relays the vendor's own re-login flow to the operator's phone" "privileged daemon"

  workplace = container "Agent Workplace" "One OS user per autonomous agent: home, ACL for the parent, kernel firewall admitting only the message broker and the egress proxy; created and removed by the dispatcher's helper; the unit of mode S" "OS user + kernel firewall"

  modelRouter = container "Model Router" "Model and effort per task class" "curator-model-router"

  networkProfiles = container "Network Profiles" "Egress profiles and conformance probe" "curator-network-profiles"

  providerLimits = container "Capacity (S3)" "Slots, per-host gates (disk, CPU idle, build lock, syspolicyd), lease transfer, validation FIFO (board part B6)" "extracted from task-board"

  registry = container "Product Registry / Keeper" "Products, projects, versioned project bindings (hosts, base, remote workplace, egress, rooms, role bindings with slots, team), up after reboot" "curator-keeper registry"

  environment = container "Environment Manager" "Role profiles, skills, MCP, command environment, managed tool homes, launch-env fragments (v3, then v4); curator playbook check" "Curator + skill-registry"

  board = container "Board" "Task management with externally configured flows (Playbook.json) under kernel guards; a client of the launcher, bridge, capacity and registry; built in Phase 4" "task-board kernel + curator-playbook" {
    taskStore = component "B1 Task Store" "Elements, status records (flow_digest, flow_generation, profile_pin), goal revisions, transition intents, resources, activity" "task-board pkg/board records" {
      tags "Store"
    }
    kernelGuards = component "Kernel Guards (kguard)" "kernel-policy/1 predicates K1-K8, checked in every mutation below configurable actions; versioned with the binary" "task-board kernel"
    flowEngine = component "B2 Flow Config and Engine" "Loads Playbook.json, narrow-checks the resolved closure, keeps the version in force and generation, turns transitions into proposals" "curator-playbook kernel seam"
    deliveryModule = component "Delivery Module" "Configurable guards, actions and events for development; kernel CR, integrate and land operations stay under kguard" "B2 module plugin" {
      tags "Plugin"
    }
    roleRouter = component "B3 Role Router" "Resolves the owner role of (type, state) to a pinned role profile and a LaunchRequest, a standing session slot, a human notice, a tool or a process" "Go"
    spawn = component "B4 Spawn" "spawn with an idempotent spawn key through the launcher; attaches RUN-* by reconciliation; never execs" "Go client of the launcher"
    goalBinding = component "B5 Board Goal Binding" "Publishes B1 goal revisions; turns outcome proposals into transition requests; blocked becomes a notice" "Board component, swarm-plugin/1 client" {
      tags "Plugin"
    }
    limitsClient = component "B6 Validation and Limits" "Spawn slots, per-host gates and the validation FIFO; the board side of S3" "S3 client"
  }
}

matrix = softwareSystem "Matrix Homeserver (a2a)" "Spaces, rooms and threads; a2a mailbox and identities" {
  tags "External"
}

modelProviders = softwareSystem "Model Providers" "Anthropic, OpenAI, local inference-manager endpoints" {
  tags "External"
}

remoteHost = softwareSystem "Remote Host" "Mac mini with subscriptions, runs the remote harness side" {
  tags "External"
}

git = softwareSystem "Git Repositories" "One repo per project" {
  tags "External"
}
