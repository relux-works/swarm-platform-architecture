Product advice record — 2026-10-05 (Curator perspective on board integration).
    Curator-side note on board integration. It agrees with the task-board maintainer's first pass.
    (B3) Role router: a role should resolve to a Curator profile reference with an exact pin, not to raw skills and instructions. The profile owns skills, instructions and MCP (as in my D1/§4.1 advice). Pin the profile digest per task alongside flow_digest, so in-flight tasks keep both their flow and their launch surface. On resume, re-resolve and refuse on drift.
    (B4) Spawn goes through curator-run composition (compose-only), then ax start --launch-plan. The board must never spell runtime flags or read fragments.
    (B5) The goal text stays a session-plane payload: never in argv or a profile, and never in the hashed managed surfaces. The board stays the author, and the provider only delivers. This matches tb-keeper's authority point.
    Also to add under 'missing': the credential mode per launch (CIP-0003: per-home, token, helper) is a launch-plan property that the board should record but never choose. Project-context mode (CIP-0002) works the same way.
