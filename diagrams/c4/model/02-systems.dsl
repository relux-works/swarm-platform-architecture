platform = softwareSystem "Swarm Platform" "Holds agent sessions, wraps their I/O, launches local and remote agents" {

  launcher = container "Launcher" "Turns a LaunchRequest into a running session: manifest, tool home, model route, limits slot, one plan, local or remote target" "Go CLI (swarm launch) over Curator + agents-management"

  sessionManager = container "Session Manager" "Holds harness processes alive: start, stop, park, restart, reboot restore; no content" "agent-session-host core (now: tb-sessiond)"

  contextManager = container "Context Manager and Bridge" "Wraps agent stdin/stdout, keeps the unified context, hosts in/out provider plugins behind a trust gate" "Go library in the holder + bridge process" {
    manager = component "Context Manager Core" "open, inject, observe, snapshot, restore, slice" "Go"
    adapters = component "Harness Adapters" "claude-stream-json, codex-app-server, muse-serve, pty-preserve; turn-state detection, unknown parks" "Go"
    journal = component "Journal and Context Store" "Normalized events, goal state, handoff packages (swarm-handoff/0)" "Files, append-only" {
      tags "Store"
    }
    bridge = component "Context Bridge" "Plugin host: binds providers to sessions, routes envelopes and output, serves tails" "Go process"
    trustGate = component "Trust Gate" "Signature, pinned identity, grant/mandate scope, freshness, deterministic checks; frames untrusted input" "Go"
    pluginApi = component "Provider Plugin Interface" "describe, bind, unbind, output, tail, receipt / manifest, envelope, cursor, health" "JSONL over stdio"
    tails = component "Tails CLI" "swarm-tail goal set/clear/status, post, park; per-session capability token" "CLI"
    matrixProvider = component "Matrix Provider" "Subscribes to rooms/threads, emits envelopes, posts output" "Plugin over a2a"
    goalProvider = component "Goal Provider" "Smart Ralph loop: nudges via stdin until done, blocked or exhausted" "Plugin"
    terminalProvider = component "Terminal Provider" "Human attach and watch" "Plugin"
    boardProvider = component "Board Provider (future)" "Placeholder: goals and spawn intents from a flow plugin" "Plugin" {
      tags "Future"
    }
  }

  harness = container "Agent Harness Session" "Claude Code, Codex, Muse or Pi process with a relocated tool home" "Native CLI" {
    tags "Harness"
  }

  trust = container "Trust" "Mandates, curator-trust grants, capability tokens" "mandate CLI + library"

  remoteHarness = container "Remote Harness" "Runs a harness on another host, tools local and jailed" "rwh"

  workerJail = container "Worker Jail" "One hardened container per tool call, patches out" "worker-jail + colima"

  modelRouter = container "Model Router" "Runtime, model and effort per task class" "curator-model-router"

  networkProfiles = container "Network Profiles" "Egress profiles and conformance probe" "curator-network-profiles"

  providerLimits = container "Provider Limits" "Host semaphore, rate limits, validation FIFO" "extracted from task-board"

  registry = container "Product Registry / Keeper" "Products, projects, project bindings, keeper processes, up after reboot" "curator-keeper registry"

  environment = container "Environment Manager" "Profiles, skills, MCP, managed tool homes, launch-env fragments" "Curator + skill-registry"

  boardPlugin = container "Board Plugin (future)" "Flow config (Playbook.json) + task management + spawn through the launcher" "placeholder" {
    tags "Future"
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
