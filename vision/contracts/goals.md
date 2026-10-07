# Contract: goals (board revisions, board-free ledger, delivery and the no-progress detector)

Status: VISION v1.2 contract draft. Fixes A-M1 (JR) and tb-keeper condition 5. Recommends D-R4 (`vision/DECISIONS-FOR-OWNERS.md`).

## 1. Who owns what

| Thing | Owner | Store |
|---|---|---|
| Board goal revision `{board, element, goal_id, rev, text, until, slot, digest, handoff_ref?}`, slot cardinality, CAS, accepted outcomes | **B1** (kernel predicate K6) | board store |
| Board-free goal (agent- or launcher-authored) | **Goal ledger**, a package of the session host with a typed API | host store |
| Delivery of either: scheduling nudges, receipts, nudge counts | **Goal provider** (a bridge plugin): a scheduler only | its delivery records in the host ledger, keyed by `(namespace, goal_id, rev)` |

The goal provider never writes the context engine's store or stdin. It calls the host's typed API through the bridge (`goal.get`, `goal.delivery_update`, `enqueue(nudge)`), and every call passes host admission (`admission-and-delivery.md` §4).

## 2. Board-free ledger

- Record: `{goal_id, rev, namespace: agent, author_principal, text, until, state: none | active | done | blocked | exhausted, budget{max_nudges, min_interval, parent_budget_ref?}}`.
- `author_principal` is derived from the caller: the session token (author = this session's agent) or the launch caller (author = launcher). It is never a payload field.
- Every change is CAS on `rev`. A child's budget is at most its parent's remaining budget.
- `swarm-tail goal set|clear|status` works only in this namespace for the session's own goals.

## 3. Board goals

- B5 publishes `goal.publish{board, element, goal_id, rev, digest, run_id, session}`, signed with the board's identity. The host stores a delivery record for exactly that revision.
- A standing session (for example `X_keeper` through `role_bindings`) can hold several board goals at once, one per slot (`slot = element`). `role_binding.max_slots` (default 1) bounds them; extra publishes are `queued` and the board is told.
- `swarm-tail goal clear --done` on a board slot is an **outcome proposal**: `goal.outcome{goal_id, rev, outcome: done, evidence_refs}` → B5 → B2 transition request (actor `run`, `own_element`). Nudging pauses (`pending_acceptance`). B1 accepts: the delivery record closes. B1 refuses: the record returns to `active`, and the refusal reason is injected as a host notice.
- `--blocked <reason>` on a board slot never becomes a transition. B5 sends a **notice** to the element's orchestrator or human owner, who decides whether to move the element (tb-keeper condition 5).
- An agent can neither set nor overwrite a board goal; a new revision comes only from B1.
- Park and resume bind to the committed revision with its `handoff_ref` (K6). A local park note is not a revision.

## 4. Nudges

On `turn.completed` + `idle` with an active goal and budget left: an `enqueue(nudge)` whose frame is `host_authored` and whose goal text keeps its author's verdict (`agent_authored` for the agent's own goal, board text labelled as the board's directive). Guards: `max_nudges`, `min_interval`, the S3 nudge budget, protocol rule 32.

Permission and question events (`interaction.pending`) are handled by `plugins-and-interactions.md`, independently of the goal loop. A goal in a session that waits on an interaction does not nudge and does not count turns.

## 5. No-progress detector (tb-keeper condition 5)

- **Shadow mode first.** During the D4 two-week trial the detector only records `would_block{session, goal, signals}`. It changes no state and sends no notice.
- Signals: N consecutive turns (default 3) with no tool call, an unchanged output digest and no change to the agent's plan or todo list. Turns of roles flagged `reasoning_turns_ok` (reviewers, architects) and every `blocked:permission` turn are excluded.
- **Activation gate:** at least 100 recorded `would_block` events labelled by a person, with a false-positive rate the owners accept (proposal: at most 2 %). Until then the detector cannot mark anything blocked.
- **After activation:** for a board-free goal it may set `blocked` and send a notice. For a board goal it only sends a `stalled` notice to the orchestrator or human owner. A detector result never triggers a board transition.
