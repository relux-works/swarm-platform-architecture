component platform.sessionHost "SessionHostComponents" "Session host internals (M1 + M2): supervisor, admission and fences, holder, Context Engine, adapters, goal ledger, host store" {
  include *
  autolayout lr
}

component platform.bridge "BridgeComponents" "Bridge internals (M3): core, trust gate, store, plugin ABI, tails, provider child processes" {
  include *
  autolayout lr
}

component platform.board "BoardComponents" "Board parts B1-B6 and the kernel guards: task store, kguard, flow config and engine, role router, spawn, board goal binding, validation and limits" {
  include *
  autolayout lr
}
