# swarm-platform-architecture

Architecture of the swarm platform rebuild (product: swarm). Owner: Alexis. Status: vision draft, under review with Ivan's side (one joint review with the R191 session-host package).

- `00-owner-concept.md`: the owner's concept (verbatim + structured).
- `vision/VISION.md`: target architecture (modules, contracts, reuse/adapt/build, open decisions, phased plan).
- `diagrams/`: C4 (Structurizr DSL) and sequences (PlantUML); rendered PNGs in `diagrams/artefacts/`. See `diagrams/README.md` to render.
- `conventions/`: engineering conventions for every module, starting with [test hermeticity](conventions/TEST-HERMETICITY.md).
- `research/`: inventories (ours / Ivan's), the herdr study, advice from ivan-curator and tb-keeper.

## Tools
| Tool | Purpose | Command | Output |
|---|---|---|---|
| structurizr-cli | validate/export C4 | `structurizr-cli validate -workspace diagrams/c4/workspace.dsl`; `structurizr-cli export -workspace diagrams/c4/workspace.dsl -format plantuml/c4plantuml -output diagrams/artefacts/c4` | `diagrams/artefacts/c4/` |
| plantuml | render sequences and exported C4 | `plantuml -tpng -o ../../artefacts/plantuml diagrams/plantuml/sequence/*.puml` | `diagrams/artefacts/` |
