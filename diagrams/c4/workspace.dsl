workspace "Swarm Platform" "Lightweight agent-swarm platform: target architecture v1 with the board as a flow plugin" {
  !identifiers hierarchical

  model {
    !include model/01-people.dsl
    !include model/02-systems.dsl
    !include model/99-relationships.dsl
  }

  views {
    !include views/context.dsl
    !include views/containers.dsl
    !include views/components.dsl
    !include styles/styles.dsl
  }
}
