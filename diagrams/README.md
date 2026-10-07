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
│   └── flow-config-load.puml        # narrow check, confirmation, atomic activation, generation fence
└── artefacts/                   # generated renders (PNG + exported C4 PlantUML), tracked; regenerate after any change
```

Matches VISION v1.2 and `vision/contracts/`. The session host (M1 supervisor + holder + Context Engine package + goal ledger + host store) and the bridge (M3 with provider child processes) are separate containers (JR A-M5, D-R7). Elements tagged `Plugin` (Matrix, goal and terminal providers, the delivery module, B5) render with a dashed border; the export keeps it as `LineStyle 10-10`. The launcher is a thin client over the composer (curator-run + agents-management). The board flow example `vision/flows/swarm-project.Playbook.json` is illustrative and non-activatable. In sequence message text, write `--` as `~--`.

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
