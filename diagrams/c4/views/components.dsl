component platform.contextManager "ContextManagerComponents" "Context manager internals: manager, bridge, trust gate, provider plugins" {
  include *
  autolayout lr
}

component platform.board "BoardComponents" "Board parts B1-B6: task store, flow config and engine, role router, spawn, board goal binding, validation and limits" {
  include *
  autolayout lr
}
