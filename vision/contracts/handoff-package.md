# Contract: HandoffPackage `swarm-handoff/2`

Status: VISION v1.2 contract draft. Fixes A-B4 (JR) and the remote half of ivan-curator objection 4. Replaces the v1 `swarm-handoff/1` (VISION v1.1 §4.4). Lifecycle per B (H:729–744, 768–788; C:779–784, 799); the schema below is A's proposal for the joint review.

Updated 2026-10-13: accepted architecture-review findings (2026-10-13), aligned to the canonical module contracts; no implementation or activation is claimed.

## 1. Rules

1. A package is a **projection** of the journal at a committed high-watermark H, made **for one recipient**. It is not a dump of session state.
2. **Allowlist, not denylist.** Only the fields in §2 exist. Anything not listed (raw transcripts, tool outputs, dirty patches, provider configs, cursors, env) stays in **protected source storage** and appears only as a reference.
3. **Secrets stay in source storage.** A secret filter runs as defence in depth, but it is not the proof. The proof is that secret-bearing material (native transcript, tool output, patches, env, provider config) is never copied into the package.
4. **Per-item provenance.** Every portable item carries who wrote it and with which verdict; a package signature only proves the issuing host.
5. **Never in a package:** tokens, `secret_ref` values, credential paths, CIP-0003 `source_ref`, live commands, pending approvals or interactions, provider cursors.

## 2. Schema

```
{ schema: "swarm-handoff/2", package_id,
  logical_session_id, source_execution_id,
  lineage: { parent_logical_session_id?, previous_package_id? },
  watermark: { journal_seq: H, journal_digest },          // committed boundary
  created_at, reason: park | crash | reboot | refresh | takeover | slice,
  policy_rev,
  audience: { kind: same_session | profile_pin | role | session,
              recipient, purpose: restore | takeover | slice, grant_ref },
  fidelity: { continuity: native_resume | seeded_rebuild, lost: [..] },
  pins: { profile, profile_pin, fragment_digest?,            // fragment digest only for same-host restore
          plan_digest, project_binding: {id, rev, digest}, base_sha },
  harness: { env_id, adapter, version, native_session_ref? }, // ref only
  goal_refs: [ { namespace: board | agent, goal_id, revision, digest } ], // agent namespace deferred (D-GOALS); not admitted
  items: [ { item_id, kind: summary | decision | open_item | event,
             text, sensitivity: internal | restricted,
             provenance: { author_principal, verdict, source_seq, source_digest, origin_sig? } } ],
  refs:  [ { kind: native_transcript | tool_output | dirty_patch | journal_range,
             ref, digest, sensitivity } ],
  sig: { key_id (host), value } }
```

- `goal_refs` replace the v1 mutable `goal{}` block (A-M1): the goal text is resolved from its ledger at seed time (`goals.md`).
- `events_tail` is gone as a field; recent events appear as `event` items only when the projection selects them (default: none for slices, the last 20 non-tool events for same-session restore).
- `fragment_digest` is omitted for cross-host packages: fragment paths are local and absolute, so it is host-bound (ivan-curator objection 4). Across hosts only `profile_pin` is compared and the restore always rebuilds.

## 3. Projections

| Projection | Default for | Items included |
|---|---|---|
| `minimal` | slices to a child, cross-profile takeover | summary, decisions, open items that the parent marks `share` |
| `restore` | same-session restore and controlled restart | `minimal` + last 20 non-tool events + `native_session_ref` |
| `full` | never default; needs an operator grant naming the recipient | `restore` + selected `tool_output`/`journal_range` refs |

Items whose verdict is `data` or `quarantine` are excluded from every projection unless the audience holds a grant for that source binding's audience. Items marked `restricted` go only to `same_session`.

Export refuses (`refused: confidentiality`) when a required item's sensitivity exceeds the audience's clearance. A redacted derivative is a new item with its own `item_id`, `provenance.author_principal = host:redactor` and its own digest; it is never presented as the original.

## 4. Protected source storage and reference resolution

- Native transcripts, tool outputs, dirty patches and journal segments live in the session host's store (owner-only permissions, host-owned).
- `host.resolve_ref(ref, caller)` returns content only if the caller is the package's audience, holds `grant_ref`, and the item's sensitivity is within its clearance. Every resolve is audited.
- A `dirty_patch` applies only into a worktree whose project binding id, revision and `base_sha` match `pins`, and only to paths inside the workdir (no `.git/`, no hooks, no symlinks out). Otherwise `refused: patch_policy`.

## 5. Seed import (restore, takeover, slice)

Before anything reaches the recipient, the host re-authorizes:
1. the package signature and `audience` against the recipient's identity and pin;
2. every pin: profile pin, binding revision and digest, base SHA, runtime per `restart-and-takeover.md` §4;
3. every goal reference against its ledger's current revision (a board goal must be the committed revision, else `refused: goal_revision`);
4. every item: its provenance verdict is kept. The first framed turn of a rebuild is `host_authored` framing that lists items under their own labels (`agent_authored` note, `data` from a peer). Prior peer content is never promoted into a user turn.

Any failure is `refused{reason}` and ends the restore path (`restart-and-takeover.md` §3). A partial seed is never presented as a restore.

## 6. Limits stated plainly

A summary loses information. Native history beyond the projection is not portable. A model can still repeat secret text it saw before the handoff; projection reduces what crosses, it does not erase what the source session knew.
