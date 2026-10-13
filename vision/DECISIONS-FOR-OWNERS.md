# Decisions for owners: joint-review conflicts D-R1 to D-R8

For Alexis + Ivan, 2026-10-05. A = VISION (this repo); B = the R191 package (agent-session-host PR #11 = H, agent-session-bridge PR #1 = C, session-split PR #1 = F). Source: `research/joint-review-sol-2026-10-05.md` §3. Recommendations are advice only; VISION v1.2 applies them as proposals until you record a decision. Each line: **A** / **B** / **Evidence** / **Rec.**

Updated 2026-10-13: accepted architecture-review findings (2026-10-13); D-R5 aligned to the adopted D-RESUME decision.

**D-R1: permission default and tracked yolo.**
A: silence = `native`; tracked `yolo` refused until a versioned ax capability exists. B: hosted sessions default to `yolo` unless configured; tracked refusal removed.
Evidence: 0018 item 5, curator advice §43, VISION §4.1; H:851–853.
**Rec.:** keep native/refusal until you and the launcher owner adopt an amendment. If hosted yolo is chosen, show the effective posture in the plan and receipt, keep deny lists and host admission, and do not claim that yolo makes framing safe.

**D-R2: unsigned peer bodies on stdin.**
A (v1.1): inject peer and unsigned bodies inside an untrusted frame. B: unsigned bodies never reach the session; signed peers are data; mode T excludes native effects.
Evidence: today's a2a pull boundary (INVENTORY-OURS:139–147); C:643, 678–684, 738–742.
**Rec.:** adopt B. Unsigned arrivals become metadata doorbells, and exact-byte operator signatures carry authority. A weak data mode is an explicit per-binding exception. v1.2 already does this (`contracts/admission-and-delivery.md` §3).

**D-R3: entrypoint, the board-free pilot and the ax dependency.**
A: `swarm launch` → compose-only → `ax start --launch-plan` for every agent. B: Curator stays the entrypoint; hosted r6 is board-primary and refuses boardless sessions without negotiation; the real ax is early and optional.
Evidence: H:859, 878–884; TBK answer:13.
**Rec.:** make `curator run` the canonical entrypoint with `swarm launch` as optional sugar. Freeze a separate board-free structured capability with its own plain park and duplex channel, without claiming r6. Also amend 0019/0021 for headless compose-only (`contracts/launch.md` §9).

**D-R4: goal truth and multiple standing assignments.**
A: the board authors; a provider delivers; one mutable goal per session. B: goals stay with the integration owner; the board owns CAS, RUN lifecycle and acceptance.
Evidence: H:732, 867–869; F:26; both advice rounds.
**Rec.:** ratify board authority. Keep immutable B1 revisions separate from delivery progress, treat a provider `clear` as a proposal only, use a separate board-free ledger, and give standing sessions slots. v1.2 does this (`contracts/goals.md`).

**D-R5: native resume, rebuild and harness upgrades.**
A: preserve when runtime, home and pin are the same, else rebuild; drift refuses. B: preserve-TUI and rebuild-structured are negotiated separately; journal H, linkage and fidelity; optimistic binary updates with last-known-good fallback.
Evidence: H:708–744, 835–850.
**Resolved by D-RESUME (2026-10-11):** the extra version-change probe recommendation is superseded. On the same machine, native resume allows a non-breaking semver change (same major; same minor for 0.x) without an extra qualification row. Keep ordinary startup qualification, approved artifact identity, harness-surface checks, native lock, home/profile/transport, auth/grants and transcript integrity; record per-harness notes for vendors known not to follow semver. A harness failure is reported as `resume-failed`; the caller decides. No automatic or portable-seed fallback on this path (session host §§3.5–3.6; wiki D-RESUME; `contracts/restart-and-takeover.md` §4).

**D-R6: carrier order and privacy.**
A: Matrix first because a2a is live. B: XMPP is the first product-carrier candidate; Matrix is doorbell-first; E2E and device lifecycle are not frozen.
Evidence: owner concept:19–25, 33; H:894, 918; C:836–845.
**Rec.:** first qualify a carrier-independent signed core plus a Matrix doorbell baseline. If the first product must promise E2E, fund XMPP and its device lifecycle as a separate prerequisite. Matrix membership is not app authority.

**D-R7: process and extension boundaries.**
A (v1.1): M2 is a library in the holder, M3 a separate JSONL plugin host, both drawn as one C4 container. B: the host owns the supervisor, adapters and journal; holders are minimal; the bridge is separate; the plugin ABI is not frozen.
Evidence: H:628–656; C:628–663.
**Rec.:** one agent-session-host codebase with the Context Engine as an internal package, minimal holders, and a separate bridge. Qualify JSONL only for carrier plugins, and scope plugin instances to credential domains. v1.2's C4 now draws it this way.

**D-R8: extraction, sequencing and approval evidence.**
A: adapt the host core; the flow seam, S3 and spawn migration happen in the fork; flows come in Phase 4. B: hybrid preferred but the SH1 replace-vs-capsule choice is open; explicit operator go; sticky legacy routing; no board-main cutover before the agreed window.
Evidence: H:633–641, 911, 920; F:10–22, 34–44; tb-keeper condition 1.
**Rec.:** first record the M0/SH1 amendment and the parity obligations. Keep legacy routes sticky. Cutover is operator-run (an R55 binary swap in the maintenance slot). State whether early S3/flow work is in the accepted scope. October 19 is the earliest possible window, not an authorization.

**What we need from you:** one decision ledger entry per row (accepted, amended or rejected), plus the owner of the resulting contract revision.
