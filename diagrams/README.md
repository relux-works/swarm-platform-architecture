# Diagrams: swarm platform target architecture

Diagrams as code for `vision/VISION.md`. Layout follows `ARCH-DIAGRAMS-SKILL.md`.

```
diagrams/
├── c4/                          # Structurizr DSL (C4)
│   ├── workspace.dsl            # minimal entrypoint, !include only
│   ├── model/01-people.dsl      # owner, operator
│   ├── model/02-systems.dsl     # platform, containers, context-manager and board components, externals
│   ├── model/99-relationships.dsl
│   ├── views/context.dsl        # SystemContext
│   ├── views/containers.dsl     # Containers
│   ├── views/components.dsl     # ContextManagerComponents, BoardComponents (B1-B6)
│   └── styles/styles.dsl
├── plantuml/sequence/           # one scenario per file
│   ├── keeper-start.puml
│   ├── worker-start.puml
│   ├── remote-worker-start.puml
│   ├── matrix-message-injection.puml
│   ├── goal-loop.puml
│   ├── context-takeover.puml
│   ├── controlled-restart.puml
│   ├── board-transition-spawn.puml  # status transition -> flow engine -> role router -> spawn
│   └── flow-config-load.puml        # Playbook validation, activation, flow version pinning
└── artefacts/                   # generated output (not committed yet)
```

Elements tagged `Plugin` (delivery module, B5 board provider) render with a dashed border. The launcher is split into a thin client and the composer (curator-run + agents-management) per VISION v1 D2. The board flow example is `vision/flows/swarm-project.Playbook.json`.

## Render

Tools: `brew install structurizr-cli plantuml graphviz` (PlantUML needs Java).

```bash
# C4: validate, then export
structurizr-cli validate -workspace diagrams/c4/workspace.dsl
structurizr-cli export -workspace diagrams/c4/workspace.dsl -format plantuml -output diagrams/artefacts/c4
plantuml -tsvg diagrams/artefacts/c4/*.puml

# Or browse interactively with Structurizr Lite
docker run -it --rm -p 8080:8080 -v "$PWD/diagrams/c4:/usr/local/structurizr" structurizr/lite

# Sequences: syntax check, then render
plantuml -checkonly diagrams/plantuml/sequence/*.puml
plantuml -tsvg -o "$PWD/diagrams/artefacts/plantuml" diagrams/plantuml/sequence/*.puml
```

Structurizr Lite expects `workspace.dsl` in the mounted directory; the includes are relative to it.
