platform = softwareSystem "Swarm Platform" "Holds agent sessions, wraps their I/O, launches local and remote agents" {

  launcher = container "Launcher (thin client)" "Turns a LaunchRequest into a launch intent: route, network, limits slot, project binding; gets one plan from the composer, hands it to M1 or M6, binds I/O and context. Never reads a fragment, spells a flag, execs or holds" "Go CLI (swarm launch)"

  composer = container "Composer" "The only composer and fragment reader: resolves the role profile, builds one Decision 0013 plan (interactive, headless, hosted-stream); compose-only for non-interactive modes" "curator-run + agents-management (one construction site)"

  sessionManager = container "Session Manager" "Plan intake (ax start --launch-plan), exec and holding: process groups, abort fences, exit classification, park, restart with pin re-check, reboot restore; no content" "agent-session-host core (now: tb-sessiond)"

  contextManager = container "Context Manager and Bridge" "Wraps agent stdin/stdout, keeps the unified context, hosts in/out provider plugins behind a trust gate" "Go library in the holder + bridge process" {
    manager = component "Context Manager Core" "open, inject, observe, snapshot, restore, slice" "Go"
    adapters = component "Harness Adapters" "claude-stream-json, codex-app-server, muse-serve (hosted-stream launch mode), pty-preserve; turn-state detection, unknown parks" "Go"
    journal = component "Journal and Context Store" "Normalized events, goal state, handoff packages (swarm-handoff/1: lock_sha256, fragment digest, no secrets)" "Files, append-only" {
      tags "Store"
    }
    bridge = component "Context Bridge" "Plugin host: binds providers to sessions, routes envelopes and output, serves tails" "Go process"
    trustGate = component "Trust Gate" "Signature, pinned identity, grant/mandate scope, freshness, deterministic checks; verdicts authoritative, host_authored, agent_authored, untrusted, reject" "Go"
    pluginApi = component "Provider Plugin Interface" "describe, bind, unbind, output, tail, receipt / manifest, envelope, cursor, health" "JSONL over stdio"
    tails = component "Tails CLI" "swarm-tail goal set/clear/status, post, park; per-session capability token" "CLI"
    matrixProvider = component "Matrix Provider" "Subscribes to rooms/threads, emits envelopes, posts output" "Plugin over a2a"
    goalProvider = component "Goal Provider" "Smart Ralph loop: goals from agent, launcher or board; nudges via stdin until done, blocked or exhausted" "Plugin"
    terminalProvider = component "Terminal Provider" "Human attach and watch" "Plugin"
  }

  harness = container "Agent Harness Session" "Claude Code, Codex, Muse or Pi process in a Curator managed tool home (HOME kept)" "Native CLI" {
    tags "Harness"
  }

  trust = container "Trust" "Mandates, curator-trust grants, capability tokens" "mandate CLI + library"

  remoteHarness = container "Remote Harness" "Runs a harness on another host, tools local and jailed" "rwh"

  workerJail = container "Worker Jail" "One hardened container per tool call, patches out" "worker-jail + colima"

  modelRouter = container "Model Router" "Runtime, model and effort per task class" "curator-model-router"

  networkProfiles = container "Network Profiles" "Egress profiles and conformance probe" "curator-network-profiles"

  providerLimits = container "Provider Limits" "Host semaphore, rate limits, validation FIFO for check sets (board part B6)" "extracted from task-board"

  registry = container "Product Registry / Keeper" "Products, projects, project bindings (hosts, rooms, role bindings), keeper processes, up after reboot" "curator-keeper registry"

  environment = container "Environment Manager" "Role profiles, skills, MCP, command environment, managed tool homes, launch-env fragments (v3, then v4); curator playbook check" "Curator + skill-registry"

  board = container "Board (flow plugin)" "Task management with externally configured flows (Playbook.json); a client of M4, M3 and S3; built in Phase 4" "task-board kernel + curator-playbook" {
    taskStore = component "B1 Task Store" "Elements, hierarchy, status records, resources (outcomes, RUN-* handles, handoff refs), activity; no flow knowledge" "task-board pkg/board records" {
      tags "Store"
    }
    flowEngine = component "B2 Flow Config and Engine" "Loads and validates Playbook.json, keeps the version in force, evaluates transitions with guards and limits, pins flow_digest per record" "curator-playbook kernel seam"
    deliveryModule = component "Delivery Module" "Guards, actions and events for development: CRs, accept_cr, integration, check sets" "B2 module plugin" {
      tags "Plugin"
    }
    roleRouter = component "B3 Role Router" "Resolves the owner role of (type, state) to a role profile and a LaunchRequest, a standing session, a human notice, a tool or a process" "Go"
    spawn = component "B4 Spawn" "One spawn interface: interactive or headless, local or remote, through the launcher; records RUN-* handles; never execs" "Go client of M4"
    goalBinding = component "B5 Board Goal Binding" "Board provider: publishes element goals to sessions through the goal provider, maps goal outcomes to transition requests, notifies human owners, keeps handoff refs" "M3 provider plugin" {
      tags "Plugin"
    }
    limitsClient = component "B6 Validation and Limits" "Spawn slots and the validation FIFO; the board side of the S3 platform service" "S3 client"
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
