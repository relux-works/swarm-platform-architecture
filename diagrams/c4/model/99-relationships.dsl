# People
owner -> matrix "Talks to keepers in product spaces"
owner -> platform.trust "Signs mandates and grants" "mandate CLI"
operator -> platform.launcher "Launches keepers and orchestrators" "swarm launch"
operator -> platform.sessionManager "Lists, attaches, parks, restarts" "CLI"

# Launcher
platform.launcher -> platform.environment "Resolves manifest into launch-env fragment" "env resolve JSON"
platform.launcher -> platform.modelRouter "Routes model and effort" "route()"
platform.launcher -> platform.networkProfiles "Resolves egress profile" "resolve()"
platform.launcher -> platform.providerLimits "Acquires a slot" "acquire/release"
platform.launcher -> platform.registry "Reads project binding" "binding()"
platform.launcher -> platform.sessionManager "Starts local session from plan" "start(plan, policy)"
platform.launcher -> platform.remoteHarness "Starts remote session" "rwh run / rwh worker"
platform.launcher -> platform.contextManager.bridge "Binds I/O providers" "bind()"
platform.launcher -> platform.contextManager.manager "Restores optional context slice" "restore()"
platform.launcher -> platform.trust "Consumes mandate for privileged steps" "mandate consume"

# Session manager
platform.sessionManager -> platform.harness "Holds process alive" "PTY / pipes"
platform.sessionManager -> platform.contextManager.manager "Grants I/O channel, asks for snapshot on park" "channel(), snapshot()"
platform.registry -> platform.sessionManager "Restores node after reboot" "up() -> resume()"

# Context manager internals
platform.contextManager.manager -> platform.contextManager.adapters "Writes stdin, reads stdout" "inject/observe"
platform.contextManager.adapters -> platform.harness "Turn input and output" "stream-json / app-server / PTY"
platform.contextManager.manager -> platform.contextManager.journal "Appends events, stores handoffs" "append/snapshot"
platform.contextManager.bridge -> platform.contextManager.trustGate "Checks every inbound envelope" "verify()"
platform.contextManager.trustGate -> platform.trust "Verifies signatures, grants, mandates" "verify/granted"
platform.contextManager.bridge -> platform.contextManager.manager "Injects admitted envelopes, observes output" "inject(lane)/observe()"
platform.contextManager.bridge -> platform.contextManager.pluginApi "Runs plugins through" "JSONL"
platform.contextManager.pluginApi -> platform.contextManager.matrixProvider "bind/output/tail"
platform.contextManager.pluginApi -> platform.contextManager.goalProvider "bind/output/tail"
platform.contextManager.pluginApi -> platform.contextManager.terminalProvider "bind/output"
platform.contextManager.pluginApi -> platform.contextManager.boardProvider "bind/output (future)"
platform.contextManager.tails -> platform.contextManager.bridge "Goal set/clear, post, park" "unix socket + session token"
platform.harness -> platform.contextManager.tails "Agent runs tail commands" "shell tool"
platform.contextManager.matrixProvider -> matrix "Subscribes and posts" "a2a / Matrix CS API"
platform.contextManager.goalProvider -> platform.providerLimits "Checks nudge budget" "acquire()"

# Harness and remote
platform.harness -> modelProviders "Model calls" "HTTPS"
platform.harness -> git "Works in project repo" "git"
platform.remoteHarness -> remoteHost "Runs remote harness turns" "ssh + unix sockets"
platform.remoteHarness -> platform.workerJail "Runs tool calls" "worker-jail run"
platform.remoteHarness -> platform.contextManager.manager "Relays turns and output" "adapter over rwh"
platform.workerJail -> git "Seeds from landed ref, exports patch" "git bundle"
remoteHost -> modelProviders "Model calls on remote subscriptions" "HTTPS"
platform.modelRouter -> modelProviders "Knows provider capabilities" "catalog"

# Future board
platform.boardPlugin -> platform.launcher "Spawn intent on status transition" "launch()"
