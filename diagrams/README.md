# Diagrams: swarm platform target architecture

Diagrams as code for `vision/VISION.md`. Layout follows `ARCH-DIAGRAMS-SKILL.md`.

```
diagrams/
├── c4/                          # Structurizr DSL (C4)
│   ├── workspace.dsl            # minimal entrypoint, !include only
│   ├── model/01-people.dsl      # owner, operator
│   ├── model/02-systems.dsl     # platform, containers, session-host, bridge and board components, externals
│   ├── model/99-relationships.dsl
│   ├── views/context.dsl        # SystemContext
│   ├── views/containers.dsl     # Containers
│   ├── views/components.dsl     # SessionHostComponents, BridgeComponents, BoardComponents (B1-B6 + kernel guards)
│   └── styles/styles.dsl
├── plantuml/sequence/           # one scenario per file
│   ├── keeper-start.puml            # launch transaction; resume compares first
│   ├── worker-start.puml            # launch stages with capacity gates and compensation
│   ├── remote-worker-start.puml     # pin-carrying intent; target composes
│   ├── matrix-message-injection.puml # admission, durable enqueue, delivery evidence, egress projection
│   ├── goal-loop.puml               # board-free goal ledger; provider schedules only
│   ├── context-takeover.puml        # fence, confirmed absence, seed or native resume
│   ├── controlled-restart.puml      # fence, drain, park, absence, eligibility, reconcile, release
│   ├── board-transition-spawn.puml  # proposal -> kguard -> intent -> role router -> spawn
│   ├── flow-config-load.puml        # narrow check, confirmation, atomic activation, generation fence
│   ├── keeper-team-start.puml       # v1.3: keeper and its standing team brought up idempotently as OS users
│   ├── spawn-with-user.puml         # v1.3: spawn through the dispatcher: grant, capacity, OS user, key, launch, retire
│   ├── external-agent-onboarding.puml # v1.3: self-signed certificate, pin, encrypted credential package, workplace
│   ├── remote-workplace-attach.puml # v1.3: remote harness attaches by SSH into its own OS user; tasks via mailbox
│   ├── mailbox-delivery.puml        # v1.3: broker verification, decision guard, doorbell, mailbox read, outbound signing
│   ├── grant-issue-and-check.puml   # v1.3: issuing, delegating (attenuation only), checking and revoking grants
│   ├── keeper-sign.puml             # v1.3: a process asks the key keeper to sign; peer-UID identification
│   ├── delegated-action-handler.puml # v1.3: an external orchestrator's command under a grant chain; handler = process or agent
│   └── action-namespace-registration.puml # v1.3: handler manifest, namespace registration (owner or agent within a prefix), issue-time check
└── artefacts/                   # generated renders (PNG + exported C4 PlantUML), tracked; regenerate after any change
```

Matches VISION v1.3 (v1.2 plus the owners' call of 2026-10-07) and `vision/contracts/`. The v1.3 sequences are not rendered yet; run the render steps below after any change. The session host (M1 supervisor + holder + Context Engine package + goal ledger + host store) and the bridge (M3 with provider child processes) are separate containers (JR A-M5, D-R7). Elements tagged `Plugin` (Matrix, goal and terminal providers, the delivery module, B5) render with a dashed border; the export keeps it as `LineStyle 10-10`. The launcher is a thin client over the composer (curator-run + agents-management). The board flow example `vision/flows/swarm-project.Playbook.json` is illustrative and non-activatable. In sequence message text, write `--` as `~--`.

## Render

Tools: `brew install structurizr-cli plantuml graphviz` (PlantUML needs Java).

```bash
# C4: validate, then export
structurizr-cli validate -workspace diagrams/c4/workspace.dsl
structurizr-cli export -workspace diagrams/c4/workspace.dsl -format plantuml -output diagrams/artefacts/c4
rm -f diagrams/artefacts/c4/*-key.puml
plantuml -tpng diagrams/artefacts/c4/*.puml

# Or browse interactively with Structurizr Lite
docker run -it --rm -p 8080:8080 -v "$PWD/diagrams/c4:/usr/local/structurizr" structurizr/lite

# Sequences: syntax check, then render
plantuml -checkonly diagrams/plantuml/sequence/*.puml
plantuml -tpng -o "$PWD/diagrams/artefacts/plantuml" diagrams/plantuml/sequence/*.puml
```

If PNG output is empty with "Can't create cache file", point Java at a writable temp dir: `export JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=$PWD/.temp`.

Structurizr Lite expects `workspace.dsl` in the mounted directory; the includes are relative to it.
