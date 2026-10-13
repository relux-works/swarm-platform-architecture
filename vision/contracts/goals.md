# Contract: goals (board revisions, board-free ledger, delivery and the no-progress detector)

Status: VISION v1.2 contract draft. Fixes A-M1 (JR) and tb-keeper condition 5. Recommends D-R4 (`vision/DECISIONS-FOR-OWNERS.md`).

Updated 2026-10-13: accepted architecture-review findings (2026-10-13), aligned to the canonical module contracts; no implementation or activation is claimed.

## 1. Who owns what

| Thing | Owner | Store |
|---|---|---|
| Board goal revision `{board, element, goal_id, rev, text, until, slot, digest, handoff_ref?}`, slot cardinality, CAS, accepted outcomes | **B1** (kernel predicate K6) | board store |
| Board-free initial goal (launching-caller authored, D-GOALS) | **Goal ledger**, a package of the session host; goal-client surface unpublished | host store |
| Delivery of either: scheduling nudges, receipts, nudge counts | **Goal provider** (a bridge plugin): a scheduler only | its delivery records in the host ledger, keyed by `(namespace, goal_id, rev)` |

The goal provider never writes the context engine's store or stdin. It schedules delivery through host admission (`admission-and-delivery.md` §4); exact goal-client actions and capability shape remain unpublished. **D-GOALS** keeps authorship with the initiating caller or the optional board/orchestrator; the agent account and the executor carrying a caller-composed plan acquire no goal-authoring capability (session host §3.8; wiki D-GOALS). Goal absence never blocks launch, attach, delivery, wake, stop or recovery. SH1 retains the existing board adapter behavior through its compatibility seam.

## 2. Board-free ledger

- Only the launching caller sets an initial board-free session goal at start through the launcher. Attribution is derived from that authenticated caller, never from a payload or possession of the session token. Revision changes retain CAS and bounded budgets; a child budget cannot exceed its parent's remaining budget.
- The former agent namespace and `swarm-tail goal set|clear|status` surface are superseded by D-GOALS and deferred to SH2+ G2. G2 must separately choose and bound self-goals or retain caller/board authorship only; no self-goal API is enabled now. The exact goal-client interface and capability shape remain unpublished.
- There is no specified board-free agent completion path. Passive `park <note>` remains a local note, never a goal revision or completion authority. Session host §3.8 owns this boundary and the remaining publication gates.

## 3. Board goals

- B5 publishes `goal.publish{board, element, goal_id, rev, digest, run_id, session}`, signed with the board's identity. The host stores a delivery record for exactly that revision.
- A standing session (for example `X_keeper` through `role_bindings`) can hold several board goals at once, one per slot (`slot = element`). `role_binding.max_slots` (default 1) bounds them; extra publishes are `queued` and the board is told.
- Under the retained SH1 board compatibility seam, `swarm-tail goal clear --done` on a board slot is an **outcome proposal**: `goal.outcome{goal_id, rev, outcome: done, evidence_refs}` → B5 → B2 transition request (actor `run`, `own_element`). Nudging pauses (`pending_acceptance`). B1 accepts: the delivery record closes. B1 refuses: the record returns to `active`, and the refusal reason is injected as a host notice.
- `--blocked <reason>` on a board slot never becomes a transition. B5 sends a **notice** to the element's orchestrator or human owner, who decides whether to move the element (tb-keeper condition 5).
- An agent can neither set nor overwrite a board goal; a new revision comes only from B1.
- Park and resume bind to the committed revision with its `handoff_ref` (K6). A local park note is not a revision.

## 4. Nudges

On `turn.completed` + `idle` with an active goal and budget left: an `enqueue(nudge)` whose frame is `host_authored` and whose goal text keeps its author's verdict (launching-caller text labelled with its admitted provenance, board text labelled as the board's directive; agent own-goal provenance is deferred with G2). Guards: `max_nudges`, `min_interval`, the S3 nudge budget, protocol rule 32.

Permission and question events (`interaction.pending`) are handled by `plugins-and-interactions.md`, independently of the goal loop. A goal in a session that waits on an interaction does not nudge and does not count turns.

## 5. No-progress detector (tb-keeper condition 5)

- **Shadow mode first.** During the D4 two-week trial the detector only records `would_block{session, goal, signals}`. It changes no state and sends no notice.
- Signals: N consecutive turns (default 3) with no tool call, an unchanged output digest and no change to the agent's plan or todo list. Turns of roles flagged `reasoning_turns_ok` (reviewers, architects) and every `blocked:permission` turn are excluded.
- **Activation gate:** at least 100 recorded `would_block` events labelled by a person, with a false-positive rate the owners accept (proposal: at most 2 %). Until then the detector cannot mark anything blocked.
- **After activation:** for a board-free goal it may set `blocked` and send a notice. For a board goal it only sends a `stalled` notice to the orchestrator or human owner. A detector result never triggers a board transition.
