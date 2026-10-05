# Contract: kernel guards ("B2 narrows only"), conformance suite and flow transactions

Status: VISION v1.2 contract draft. Fixes A-B5, A-M8 and A-M9 (JR) and tb-keeper condition 2. Implements the line adopted in v1.1 §0.1 (`research/tb-keeper-board-advice-2026-10-05.md`).

## 1. Where "narrow only" is enforced

Two layers. The second one is the enforcement point; the first only refuses early.

1. **Load-time narrow check** in flow-config-load: rejects a Playbook whose resolved closure would relax a mandatory predicate (§3).
2. **Kernel guard (`kguard`)**: a fixed layer inside the mutation owners, **below** every configurable guard, action and module. It runs in the same transaction as the mutation, after B2 has decided and before the write commits, whatever the Playbook says and whether or not a module plugin is loaded.

B2's output is a **proposal**, never a write: `TransitionProposal{intent_id, element, from, to, actor, flow_generation, expected_rev, evidence_refs[]}`. Only B1 `write_status` and the delivery kernel operations (`cr.*`, `integrate`, `land`) mutate, and each calls `kguard` first.

`kguard` reads an immutable policy table, **`kernel-policy/1`**, compiled into the kernel binary. It is versioned with the binary, not with any repo. It changes only through a kernel release that the operator installs by binary swap (tb-R55). A person confirming a flow version (PB §2.4) cannot waive a kernel predicate. A missing mandatory module (for example the delivery module for a CR-bearing type) makes the mutation refuse (`refused: module_missing`); there is no fallback to "no check".

## 2. Mandatory predicates (`kernel-policy/1`)

| Id | Invariant (v1.1 §0.1) | Mutation owner that enforces it | Predicate checked by `kguard` |
|---|---|---|---|
| K1 | CR lifecycle and its state machine | delivery kernel `cr.transition` | only kernel-defined CR transitions; a leaf with a CR reaches `integrating`/`done` only with CR state `accepted` |
| K2 | Story worktree isolation, checkpoint and converge, stale-tree check (tb-R182) | worktree manager, before spawn into a story worktree and before integrate | worktree belongs to the story; checkpoint present; tree not stale |
| K3 | Integrate and landing transactions: signed exact-head ff, junction proof (R69/R71, tb-R189, tb-R192) | `integrate` / `land` | signed exact-head fast-forward; junction proof; no other path writes the target branch |
| K4 | Validation FIFO and machine ceilings (B6) | S3 `queue` / `acquire` / `admit_host` | check-set evidence comes from a FIFO run record; `limit` never above the machine ceiling; per-host gates (`launch.md` §5) |
| K5 | Review-contract evidence (R141/R170, carry-over R161) | B1 `write_status` into review-terminal states | a review evidence record (table, verdict, carry-over) exists for the reviewed revision |
| K6 | Board goal revisions with `handoff_ref` (session-host §8) | B1 goal ledger | CAS on goal revision; park/resume refuse without a committed revision; no flow-writable goal field |
| K7 | Activity and audit logs, resources, evidence store (R185/R186) | B1 | every mutation appends its audit line in the same transaction; append-only; evidence is immutable |
| K8 | Store base invariants and resource hygiene (R176) | B1 | unique ids, existing parent, optimistic `rev`, NUL-free resource names and content metadata |

Protected states are named by **state class**, not by name, so a renamed state cannot escape: a Playbook maps each of its states to a kernel class (`work`, `review`, `integration`, `terminal_success`, `terminal_other`, `blocked`). An unmapped state is refused at load.

## 3. Load-time narrow check

Run on the **resolved inheritance closure** (`extends`/`uses` pinned by digest) plus its migrations, before confirmation and before activation. It rejects with `widen:K<n>:<rule>`:

| Rule | Rejected when the resolved Playbook |
|---|---|
| `K1.cr_bypass` | has a path into `integration` or `terminal_success` for a CR-bearing type that skips the CR acceptance action |
| `K2.worktree` | declares `spawn.owner` into a story worktree without the worktree module, or disables the stale-tree check |
| `K3.land_override` | defines or replaces an action named `integrate`, `land` or `cr.*`, or adds a transition into `integration` without the kernel landing action |
| `K4.ceiling` | sets a `limit` above the machine ceiling, or a check set that does not go through `queue` |
| `K5.review_bypass` | reaches `terminal_success` from a non-`review` class without review evidence (including through a wildcard `*`) |
| `K6.goal_write` | declares an action or field that writes a goal revision or `handoff_ref` |
| `K7.audit` | disables or filters activity, audit or evidence writes |
| `K8.class` | leaves a state without a kernel class, or maps two classes ambiguously |
| `M.migration` | strands elements (no migration for a removed or reclassified state) |

The check is not the enforcement point: if it is bypassed, `kguard` still refuses at mutation time.

## 4. Conformance suite (tb-keeper condition 2)

Location (proposed): `task-board/conformance/narrow-only/`. Runs in CI on every kernel change and every flow change, and before any Playbook activation.

- **Negative fixtures, one per rule in §3 at least** (and one per predicate K1–K8): a Playbook that relaxes exactly that invariant. Each must (a) be rejected by flow-config-load with the expected `widen:` code, and (b) with the load check bypassed (the fixture injected straight into the engine), have the resulting mutation refused by `kguard` with `refused: K<n>`.
- **Positive fixtures**: narrowing edits (an added guard, a lower `limit`, a new pre-review state, an extra required field) are accepted and change behaviour only in the narrowing direction.
- **Coverage gate**: the suite fails if `kernel-policy/1` has a predicate without a negative fixture.

**PC1 behaviour-equivalence gate.** Before any flow change after the PC1 seam: the full spm suite plus regress pass unchanged (no test edited, same pass set) under the built-in default playbook at its pinned digest, and a replay of a recorded production board log produces the same status records except for the added `flow_digest`/`flow_generation` fields.

## 5. Transition and action transactions (A-M8)

- **Intent first.** In one B1 transaction: check `expected_rev` and `flow_generation`, run `kguard`, write the status record, write a `TransitionIntent{intent_id, actions[], state: pending}`.
- **Idempotent actions.** Each action has the key `(board, element, transition_rev, action_index)`. `spawn.owner` passes it to B4 as `LaunchRequest.request_id`; the launcher and the host dedupe by it (`launch.md` §2).
- **Run attachment by reconciliation.** B4 attaches `RUN-*` after the launch result. On a crash, B2's recovery scans `pending` intents, asks the host `list(request_id)`, attaches an existing run or re-issues the same key.
- **Generation fence.** A transition evaluated under generation g and committing under g′ ≠ g is re-evaluated. Activation is one B1 transaction: take the activation lock (transitions wait), apply the migrations, set the version in force, bump `flow_generation`, release. Migrations run before the new version is visible, never after.
- **Completion is a proposal.** A run's `goal clear --done` becomes a transition request; B1's acceptance (or refusal with reason) is the outcome (`goals.md` §3).
- **Recorded launch metadata.** StatusRecord, `RUN-*` and `board_ref` carry `flow_digest`, `flow_generation`, `profile_pin`, `credential_mode` and `project_context_mode` (recorded, never chosen).
- Flow activation's human confirmation and the kernel predicates are separate authorities; neither substitutes for the other.

## 6. The Playbook example (A-M9)

`vision/flows/swarm-project.Playbook.json` is **illustrative and non-activatable**. Its base (`task-board-default`) and the validator are not in this repo. Before it may be activated: pin the base by digest, publish the resolver's override semantics and validator version, and pass §3 and §4 on the resolved task, bug and design graphs, including reachability, `bug` field availability, actor restrictions on `*→closed`, and an explicit `testing → to-review` success path that does not rely on an inherited wildcard.
