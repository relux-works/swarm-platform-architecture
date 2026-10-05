# Diagrams: swarm platform target architecture

Diagrams as code for `vision/VISION.md`. Layout follows `ARCH-DIAGRAMS-SKILL.md`.

```
diagrams/
├── c4/                          # Structurizr DSL (C4)
│   ├── workspace.dsl            # minimal entrypoint, !include only
│   ├── model/01-people.dsl      # owner, operator
│   ├── model/02-systems.dsl     # platform, containers, context-manager components, externals
│   ├── model/99-relationships.dsl
│   ├── views/context.dsl        # SystemContext
│   ├── views/containers.dsl     # Containers
│   ├── views/components.dsl     # ContextManagerComponents (manager, bridge, providers)
│   └── styles/styles.dsl
├── plantuml/sequence/           # one scenario per file
│   ├── keeper-start.puml
│   ├── worker-start.puml
│   ├── remote-worker-start.puml
│   ├── matrix-message-injection.puml
│   ├── goal-loop.puml
│   ├── context-takeover.puml
│   └── controlled-restart.puml
└── artefacts/                   # generated output (not committed yet)
```

Elements tagged `Future` (board plugin, board provider) are placeholders and render dashed.

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
