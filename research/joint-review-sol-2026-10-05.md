# Joint architecture review

## 1. Verdict on A and ranked findings

**Verdict: request changes before contract freeze or extraction approval.** A is a useful product/module proposal, but its v1.1 contracts are not yet safe implementation contracts. Keep its one-composer rule, tool-home choice, board-free goal loop, role-profile pins, and board-as-client direction. Converge on B's supervisor/holder separation, host-enforced admission, delivery evidence, and restart fences. B is substantially stronger on security and recovery, but remains a proposal with unresolved capability gates; it is not an implemented replacement to which A can simply delegate the gaps.

Scope: reviewed `00-owner-concept.md`, all supplied `research/*.md`, `vision/VISION.md`, the Playbook example, C4 DSL, sequence sources, exported C4 PlantUML, PNG embedded sources, and all three R191 diffs. No implementation repositories or linked PR #8/#9 branches are supplied. Inventory claims are documentary evidence, not independently verified runtime behavior. B itself identifies its missing branch artifacts (`r191/agent-session-host-PR11.diff:624,928,941`).

Citation convention for B, used throughout sections 1–3 and 5:

- **H** = `r191/agent-session-host-PR11.diff`; **C** = `r191/agent-session-bridge-PR1.diff`; **F** = `r191/session-split-PR1.diff`.
- `H:824` means line 824 of that exact local diff, not line 824 of the proposed upstream file. Ranges are inclusive. Section 4 separately gives actual **new-side upstream file lines**, with their local diff anchors, so comments can be posted correctly.
- Blocker = prevents freezing or advertising the affected contract; major = likely failure or material architectural debt; minor = documentation/traceability defect. Findings do not demand that every deferred capability be implemented now: explicit refusal and deferral are acceptable fixes.

### Blockers

**A-B1 — Admission authority is neither complete nor enforced at every mutation boundary.**

**File:section:** `vision/VISION.md:127–143` (§§4.5–4.7), `vision/VISION.md:89–91,118–125`; `diagrams/plantuml/sequence/matrix-message-injection.puml:15–29`; `diagrams/plantuml/sequence/worker-start.puml:52–61`.

**Failure:** the optional-signature Envelope has no signed target/session, action, expiry, grant references, policy/binding revision, or immutable-byte representation. A provider can claim a sender, replay a signed body against a different session, or change framing without a defined verification contract. The diagram delivers unsigned bodies as stdin turns; text framing does not constrain a model's resulting tool effects. Launcher goals, tail commands, context restores, direct M1 stop/restart/takeover, and human attach are not explicitly brought under the same admission rule. Calling a provider's framing `host_authored` also lacks a rule preventing provider-selected goal text from acquiring host authority. The old a2a content boundary deliberately avoided near-user-authority delivery (`research/INVENTORY-OURS.md:139–147`).

**Fix:** freeze immutable application envelopes with exact target/action/hash/expiry/grant/binding fields; derive provenance from authenticated caller and binding, never payload claims. Enforce admission in the host at every typed mutation, including seed imports, bind changes, goals, approvals and attach. Separate transport-admitted data from operator instructions and effect authority. Default unsigned arrivals to quarantine or metadata-only doorbells. If owners explicitly retain unsigned data delivery, expose it as a weaker, separately authorized mode with no complete-mediation claim. Adopt B's mode T/S exclusions and reauthorization rules (H:659–701; C:643,669–684,734–773); framing is supplementary, as B correctly states (H:670).

**A-B2 — Controlled restart can reopen admission after refusing restore, and can start before the old execution is absent.**

**File:section:** `vision/VISION.md:108–124` (§§4.2–4.4); `diagrams/plantuml/sequence/controlled-restart.puml:13–37`; `diagrams/plantuml/sequence/context-takeover.puml:29–54`.

**Failure:** controlled-restart closes M3 only, asks for a note, sends `stop`, and immediately composes/executes without a confirmed exit or settled effects. A detached tool, approval, push, or landing can remain active. The drift branch returns refusal at line 29, but lines 35–36 still reopen admission and deliver held envelopes. Context-takeover similarly rebinds, injects and reports restored after its refusal branch. A new launch or retry can bypass bridge closure, or a daemon crash can erase the closure, yielding two writers or a false success report.

**Fix:** use a persisted host admission fence serialized with start/wake/retry/probe; distinguish that ordinary closure from an update lock. Drain turns, interactions and external effects; require confirmed absence or authenticated custody transfer before any replacement. A failed stop, unresolved native delivery, auth failure, pin drift, or seed uncertainty must terminate the restore path with closure retained. Only a successful, eligible reconciliation can release delivery; explicit stops stay stopped. For board sessions, require the committed goal revision with `handoff_ref` as ready evidence, not merely a local note. B has the necessary outline (H:813–831; H:405–464), though plain-session semantics remain open (H:880–883).

**A-B3 — At-least-once delivery is specified without a durable admission/dispatch recovery contract.**

**File:section:** `vision/VISION.md:116,123,129–131`; `diagrams/plantuml/sequence/matrix-message-injection.puml:14–42`; `diagrams/plantuml/sequence/context-takeover.puml:44–49`.

**Failure:** a native prompt is applied, the host dies before its receipt, and resume replays the “undelivered” envelope. An `id` alone neither binds bytes nor distinguishes two principals or carrier rewraps. A changed body under a reused ID can be mistaken for a harmless duplicate. Advancing a provider cursor after mailbox persistence is reasonable, but does not establish host acceptance or native application. No durable queue/outbox ownership, ordering, replay retention, revocation-at-dispatch, or clock/backup rollback rule exists. “Delivered” can mean a pipe write rather than application.

**Fix:** specify bridge-local atomic admission plus a durable idempotent host enqueue, with acceptance only after the host's durable acknowledgment. Track accepted/queued/dispatched/applied/refused/unknown evidence, principal-scoped ID→hash claims, sequence/gap policy, stable origin IDs across carriers, and reflection rejection. Reconcile unknown native outcomes before replay; never automatically replay historical approvals. Freeze tombstone retention/anti-replay floors and storage failure behavior. B's bridge handoff explicitly avoids a fictitious distributed transaction (C:676,698–708,823–834,900); adopt that contract and resolve H's less precise atomic-commit wording (H:692).

**A-B4 — “Never secrets” and portable handoff authority are assertions rather than enforceable boundaries.**

**File:section:** `vision/VISION.md:120–125` (§4.4), `vision/VISION.md:109,129,132`; `diagrams/plantuml/sequence/context-takeover.puml:18–25,37–40`; `diagrams/plantuml/sequence/matrix-message-injection.puml:44–49`.

**Failure:** a tool emits a token, private file, credential path, or malicious instruction into `events_tail`/summary/open items/provider config; a full handoff or child slice forwards it to another role or room. Removing explicit `secret_ref` fields does not remove secrets inside free text, transcript references or dirty patches. One package signature proves the package issuer, not each original author or the recipient's right to see the content. A rebuild promotes prior peer content into its first turn without renewed authorization. `session_id`/lineage do not distinguish logical session from fresh execution or identify a committed journal boundary. Dirty patch application and reference resolution have no recipient/path policy.

**Fix:** define a versioned, recipient-authorized `HandoffPackage` at committed high-watermark H with logical-session/execution linkage, per-item provenance, source digests, audience, policy revision, supported fidelity, and an explicit exclusion of live commands/approvals. Use an allowlisted portable projection; keep potentially secret-bearing native evidence in protected source storage and resolve references through caller-authorized APIs. Apply audience/grant checks to ordinary output too: the Matrix sequence currently forwards text and tool-call events straight to the thread, with no separately scoped transcript permission. Default to minimal state/decision projections. Redact separately signed derivatives and refuse export when the required confidentiality cannot be established; secret filters alone cannot prove absence. Reauthorize every imported item, pin, goal revision and project snapshot before seed. Document summary loss and native-history limitations. B provides the right lifecycle, not yet a final schema (H:729–744,768–788; C:779–784,799).

**A-B5 — The v1.1 “B2 may only narrow” invariant has no defined enforcement point below configurable actions.**

**File:section:** `vision/VISION.md:22–30` (§0.1), `vision/VISION.md:161–176,213–216` (§5); `diagrams/c4/model/02-systems.dsl:45–50`; `diagrams/plantuml/sequence/flow-config-load.puml:17–40`.

**Failure:** the amendment correctly reserves CR lifecycle, worktree isolation, landing proofs, review evidence and goal revisions outside B2. But B1 then promises only IDs/parent/history/rev, “everything else” belongs to B2, and delivery machinery is described as a B2 plugin. The activation diagram never evaluates narrowing of mandatory invariants. A confirmed Playbook can omit a guard/action or replace an inherited transition, and it is unspecified which non-optional kernel/domain gate still prevents an unsafe integration. Human confirmation must not authorize bypassing the invariant.

**Fix:** enumerate mandatory kernel/platform/domain predicates and enforce them in the actual mutation owners, regardless of B2 configuration or plugin availability. B2 selects transitions and adds restrictions; it cannot substitute for those checks. Validate the resolved inheritance closure and migrations against that immutable policy before confirmation and activation. Make missing mandatory modules refuse. Add the check to source diagrams and the example's validation contract. This implements the advice already adopted, rather than inventing a new board policy (`research/tb-keeper-board-advice-2026-10-05.md:3–13`).

### Major

**A-M1 — Goal revision authority leaks into a mutable delivery state machine.**

**File:section:** `vision/VISION.md:31,135–139,165,207–209,248`; `diagrams/plantuml/sequence/board-transition-spawn.puml:53–68`; `diagrams/plantuml/sequence/goal-loop.puml:13–18,47–59`.

**Failure:** the amendment preserves board authorship, but the package has one mutable `goal{text,author,...}` without goal ID/revision/slot/digest/CAS. The provider changes it to done before B2 accepts the transition; a guard refusal or stale role leaves development active but nudging stopped. A generic own-session `goal set|clear` can overwrite/clear a board-owned goal. Multiple board elements assigned to a standing keeper collide in one goal field. A local park note is not the board's committed revision.

**Fix:** B1 owns board-goal revisions, slot cardinality, CAS and accepted outcomes; B5 sends typed publish/delivery/outcome proposals keyed by board/element/run/goal revision. The provider owns only scheduling and receipts for that revision. Clearing a board goal requires the board acknowledgment; refusal leaves it active or explicitly pending/blocked. Give the board-free loop its own authoritative ledger namespace, with caller-derived agent authorship and parent/child budget limits. H:732,867–869 and F:26–30 retain external goal ownership; advice explicitly requires that distinction (`research/tb-keeper-board-advice-2026-10-05.md:13`; `research/curator-board-advice-2026-10-05.md:5`).

**A-M2 — LaunchRequest is a field list, not a negotiated launch transaction.**

**File:section:** `vision/VISION.md:89–93,109,199–204`; `diagrams/plantuml/sequence/keeper-start.puml:35–59`; `diagrams/plantuml/sequence/worker-start.puml:21–33,46–61`.

**Failure:** `runtime`, `task_class` versus explicit model/effort, permissions, `transport`, mode, context strategy and `native_goal` have no precedence or allowed-combination rules. Pi is a request runtime but has no named M2 adapter. `env` and `network_profile` have no defined defaults. No request ID, caller authority, schema/capability version, exact profile pin input, credential/project-context metadata, rejection vocabulary or cancellation/rollback is defined. `launch` returns only after starting, binding and restoring, so a bind failure can orphan a running process. An exec-before-seed/bind session can consume unexpected input before initialization. The no-slot diagram branch rejoins composition and start instead of stopping. Worker-start line 18 passes `--goal`, which §4.6 explicitly says the launcher refuses (`vision/VISION.md:136`); the client goal-payload spelling needs a separate, explicit contract.

**Fix:** publish versioned request/intent/plan/launch-result schemas with a capability matrix and separate execution mode, adapter transport, continuity policy and assurance mode. Resolve precedence once; bind plan/context/project/binding digests and effective permissions. Define prepare/admit/start/initialize/ready stages and compensations; expose input only after required initialization. Transfer a capacity lease to the process owner, including failure cleanup. A new `swarm launch` frontend must wrap the agreed Curator intake, not impersonate an implemented `ax` command. B still refuses boardless hosted r6 and requires a new capability (H:878–884); do not silently expand it.

**A-M3 — Project binding is not an authorization or reproducibility contract.**

**File:section:** `vision/VISION.md:84,90–91,151,199,253`; `diagrams/plantuml/sequence/remote-worker-start.puml:16–41`.

**Failure:** a mutable registry switches an allowed host, jail project, repository, role binding or room between planning and dispatch. “ref policy” does not prove an exact landed commit, and an allowed host name does not establish its authenticated identity. A remote target resolves a newer/different profile than the local intent. A standing role alias may point to an unrelated session. It is unspecified where remote egress policy is actually applied, where data audiences are checked, or who can change a binding. A first-attach mandate alone does not authorize every subsequent request or a changed binding.

**Fix:** version and hash an operator-authorized binding with product/project identity, repo identity, exact base SHA, worktree/dirty-state policy, authenticated host/security domain, jail scope, egress policy, allowed audiences/classes and role-session compatibility. Pin it in intent, admitted plan, run record and handoff. Target resolution must return the actual accepted pin/plan digest and reject drift; recheck binding/grants at dispatch and resume. Keep local workspace and remote execution identities distinct. Define refusal for unavailable host, wrong base and protected credential lookup failure.

**A-M4 — Plugin processes have no least-privilege or durable lifecycle contract.**

**File:section:** `vision/VISION.md:64–65,127–143` (§4.5); `diagrams/c4/model/02-systems.dsl:15–21`.

**Failure:** one process per provider multiplexes sessions yet receives free-form configs/outputs/tails. A compromised provider can forge `sender`, claim another binding or request broader tails. The host-to-plugin `secret_ref` conflicts with “providers re-resolve secrets” unless the broker's authorization is specified. Stdio offers no process isolation by itself; inherited HOME/env/descriptors can expose session tokens, credentials or unrelated stores. Unbounded JSONL/log output can stall the host, and a restart has no defined cursor/receipt recovery.

**Fix:** specify install/probe trust, plugin executable/version pinning, host-assigned binding handles, per-binding grants, caller-authenticated secret resolution, sanitized environment and descriptor inheritance, frame size/time/rate/queue limits, correlation IDs, version negotiation, shutdown/restart recovery and log separation. Choose provider-instance scope according to credential/security domains rather than just provider name. Same-UID is explicitly only a guardrail (`vision/VISION.md:143`); do not claim containment without an evidenced broker/OS boundary. B describes carriers and scopes, but does not yet settle the transport-process ABI (C:628–663).

**A-M5 — M1/M2/M3 ownership is inconsistent across prose, C4 and sequence calls.**

**File:section:** `vision/VISION.md:62–72,129,135,242`; `diagrams/c4/model/02-systems.dsl:7–22`; `diagrams/c4/model/99-relationships.dsl:24,33–42`; `diagrams/plantuml/sequence/goal-loop.puml:17,34,51`; `diagrams/plantuml/sequence/board-transition-spawn.puml:55`; `diagrams/plantuml/sequence/context-takeover.puml:22`.

**Failure:** M2 is a library plus journal store inside a holder, M3 is a separate process, but C4 makes them one container. External goal plugins directly mutate M2 in the sequences even though their JSONL vocabulary only allows envelopes/cursors/health/log and the bridge is the route to M2. D4 says goal state is in the provider; §4.6 says M2. M1 “never reads content” yet context-takeover lets it query M2's journal store; “modules share no stores” is thereby contradicted. The board “calls M4/M3/S3 only” while diagrams and §5.6 also require S4, S6 and M5. Splitting deployment according to these documents would create undefined RPCs and crash ownership.

**Fix:** make Context Engine an internal host package with a host-owned journal, accessed through typed APIs; keep a minimal holder free of goal/journal semantics. Make Bridge a separate C4 container and transport plugins explicit child processes. Route every plugin request through M3; give board-free goal authority an explicit service/API. M1 may orchestrate opaque handoff references through the engine, never directly read its store. Publish the real dependency list; low coupling means contracts and one writer, not denial of required dependencies. B's holder explicitly has no goals/board/channel semantics (H:645–656).

**A-M6 — Resume freshness and preserve/rebuild semantics are incomplete.**

**File:section:** `vision/VISION.md:109–124,258`; `diagrams/plantuml/sequence/keeper-start.puml:54–59`; `diagrams/plantuml/sequence/context-takeover.puml:35–51`.

**Failure:** §4.2 re-resolves through the composer but §4.4 uses the “stored plan.” A raw plan can contain credential-bearing environment values, and replaying it can restore stale permissions, network/binding policy or revoked credentials. Same runtime/home/pin is necessary, not sufficient: native history compatibility, selected binary identity, transcript integrity, exclusive native-session custody, auth readiness and current grants must also hold. The keeper diagram rebuilds on changed pin without showing default drift refusal. A and B also overload preserve/rebuild: A defines continuity strategy, B includes native TUI versus structured launch surfaces. Rebuild fidelity is unstated.

**Fix:** persist a secret-free launch recipe, digests and native handles; recompute the effective plan from current authorized environment and protected credential resolution. Compare context pins and effective posture, negotiate runtime identity/probes and require exclusive custody. Keep logical session stable and give each execution fresh IDs. Model transport and continuity as distinct dimensions with supported combinations; native resume and seeded conversation are not equivalent. Unsupported export/seed, auth, pin, version or state combinations park/refuse. B explicitly avoids persisted env and distinguishes loss of hidden/native state (H:729–736,824–850).

**A-M7 — Native permission responses and human terminal ownership are unspecified.**

**File:section:** `vision/VISION.md:110,115–117,137–143,251`; `diagrams/plantuml/sequence/matrix-message-injection.puml:24–39`; `diagrams/plantuml/sequence/goal-loop.puml:26–32`.

**Failure:** Q2 says a signed answer returns as an authoritative Envelope, but M2 says blocked/unknown injection refuses and parks. There is no typed approval operation binding request/session/execution/revision/allowed answer; an answer can arrive after the dialog changed or target a new execution. Human attach/detach is not connected to an exclusive input lease, so a human typing and next-turn injection can race. Generic signed user turns cannot safely answer permission dialogs. The goal loop nests permission handling inside an idle/turn-completed loop, which does not demonstrate handling a live blocked turn.

**Fix:** add typed pending-interaction events and CAS approval responses, with expiry, exact native request and execution/turn identity; first valid authorized answer wins. Reject historical answers on resume. Human raw terminal control is a broad, separately granted lease that suspends automated injection; unknown readiness parks. Pin readiness grammar/probes to the admitted harness release: herdr's idle fallback and remotely updated manifests cannot be reused as-is (`research/herdr-study.md:25,64,69,88`). Process permission events independently of goal progress. B makes these distinctions (H:717–727,745–758).

**A-M8 — Flow activation, transition actions and role pins lack transaction/recovery semantics.**

**File:section:** `vision/VISION.md:32–34,90,169–177,197–209`; `diagrams/plantuml/sequence/flow-config-load.puml:22–42`; `diagrams/plantuml/sequence/board-transition-spawn.puml:28–55`.

**Failure:** a status is committed then spawn runs; a crash between them strands the element, while a crash after start and before RUN attachment can spawn it twice on retry. Activation precedes migrations in the diagram, exposing elements to a new version while they still use old states. Concurrent transitions can be evaluated under one flow and committed after another becomes active. `profile_digest` is mandated by v1.1 but absent from Element/StatusRecord/board_ref schemas and role-router output; credential/project-context recording likewise has no fields. B1's rev alone does not serialize activation, migration, assignment and goal publication.

**Fix:** use durable transition/action intents and an idempotent spawn key (board, element, transition revision, action index), with run attachment and reconciliation. Bind evaluation to expected element revision and active flow generation; reject/re-evaluate if either changes. Atomically activate a prepared migration or fence transitions during it. Persist exact resolved role profile references/digests and effective launch metadata. A completion remains a proposal until B1 accepts it. Keep flow activation's human authority distinct from mandatory kernel checks.

**A-M9 — The Playbook example is not sufficient evidence of safe inheritance or testing flow.**

**File:section:** `vision/flows/swarm-project.Playbook.json:3–4,18–26,41–74,87–95`; `vision/VISION.md:174–178,182–194`; `diagrams/plantuml/sequence/flow-config-load.puml:17–18`.

**Failure:** the example shadows inherited wildcard transitions without a supplied base playbook or validator. The required `test` field is declared for `task`, while the `leaf` workflow also serves `bug` (`vision/VISION.md:182`); no bug inheritance/default is shown. There is no explicit testing→to-review success transition; inherited `*→to-review` and `*→reviewing` may permit bypassing the intended test pass, while mandatory kernel checks are not spelled out. Design `*→closed` has no explicit actor/reason guard. These are unresolved behavior, not proven bugs in an absent resolver. The diagram assumes a committed lock which the example does not identify.

**Fix:** include a pinned base and resolution/override semantics, schema and validator version. Validate the fully resolved task/bug/design graphs, field availability, reachability, actor restrictions, non-bypassable test/review evidence and closure authorization. Make testing success and permitted skips explicit; prohibit relying on inherited wildcard behavior until the resolved graph is reviewed. Label this example illustrative and non-activatable until those checks exist. It already admits it is unchecked (line 3); do not present it as a frozen flow contract.

**A-M10 — Phase 0 is feasible as existing operations, not as the promised unified platform.**

**File:section:** `vision/VISION.md:49–54,224–232,258–264`; `research/INVENTORY-IVANS.md:23,26–32,50–52,96`; `research/INVENTORY-OURS.md:13–14,54,76,101–108,162`; `research/curator-advice-2026-10-05.md:20–26,54–68,85–89`.

**Failure:** `ax` has no session command behavior, host/bridge are specs, curator-run ships interactive composition, keeper/trust/playbook are unimplemented, fragment-v4 strict discovery/tails and duplex hosting are new. Mandates has no real presence key in the inventory. Current rwh does not preserve context across restart or use agents-management's plans. Phase 0 can operate those distinct paths, but cannot demonstrate “exactly declared” context, unified launch, automatic portability, or the target trust boundary. Calling M5/S1–S7 simply REUSE disguises substantial design/adoption work. B likewise freezes boardless hosted r6 as refused (H:880).

**Fix:** distinguish a documented Phase-0 baseline from later advertised capabilities; enumerate missing prerequisites and proof gates. Produce reviewed contract drafts now, not a claim that they are delivered schemas. Use only existing paths in the baseline and preserve their current guarantees. Build one newly negotiated board-free structured vertical after review; defer mesh, S isolation, multi-harness parity, automated keeper registry, flow activation and cross-host resume until independently evidenced. The host compatibility facade is an early migration dependency even though configurable board flows remain last.

### Minor

**A-N1 — Versions and missing normative sources are not traceable.**

**File:section:** `vision/VISION.md:3,18,174–177,231`; `vision/flows/swarm-project.Playbook.json:3–4`; `diagrams/README.md:5,30`.

**Failure:** the header still calls the proposal v1, `research/playbook/` and its default example are absent, and `ARCH-DIAGRAMS-SKILL.md` is not supplied. A reviewer cannot independently resolve PB §7 override rules or identify the exact adopted protocol revision.

**Fix:** label the reviewed revision v1.1, cite repo+commit+path for external normative sources, provide the resolved Playbook evidence before activation, and remove or supply dangling local references. Do not confuse research advice with adopted protocol.

**A-N2 — The diagrams are valid and current renders, but not faithful deployment boundaries.**

**File:section:** `diagrams/c4/model/02-systems.dsl:9–22,44–58`; `diagrams/artefacts/c4/structurizr-Containers.puml:38–39`; `diagrams/artefacts/c4/structurizr-BoardComponents.puml:25,28`; `diagrams/README.md:29,32`.

**Failure:** M2's library, M3's process and plugin processes are components of one C4 container; external B5 is both a board component and an M3 plugin. Generated C4 marks the delivery/board plugins with empty tags and does not preserve the README's promised dashed-plugin treatment. The README says artifacts are not committed yet although supplied PNGs are tracked. Readers can mistake package dependency for process custody. The substantive ownership error is A-M5.

**Fix:** distinguish package/component, process/container and deployment views; choose B5's process ownership explicitly and draw its board API dependency. Preserve plugin tags/styles in export and update artifact instructions. Re-render after semantic fixes; current PNG metadata matches all 13 supplied PlantUML sources, so this is not an old-image defect.

**A-N3 — Newly scoped platform services have no module identity or contract.**

**File:section:** `vision/VISION.md:36–43,69,145–153`; `diagrams/c4/model/02-systems.dsl:34–58`.

**Failure:** remote board, evidence store, resources, commit identity, binary swap, CI topology and per-host build lock are added “to scope,” but are neither assigned owners nor consistently represented. S7 has no contract. Integrators can assume safety-critical facilities are inside a generic service label.

**Fix:** identify existing external services and their capability/evidence interfaces; name the responsible owner and migration gate for each. Explicitly defer facilities that are outside the pilot instead of leaving hidden prerequisites.

### Phase-0 feasibility check

| Existing part | What the supplied evidence supports now | Boundary the baseline must retain |
|---|---|---|
| Curator + curator-run + agents-management | Managed tool homes and interactive plan composition; published agents-management plan values (`research/INVENTORY-IVANS.md:22–23,41–45,50`; `research/INVENTORY-OURS.md:86–89`) | One-time Claude login per managed home; no shipped strict exact-set or typed duplex/headless composer claim (`research/curator-advice-2026-10-05.md:13,20–26,54–68`) |
| tb-sessiond / task-board spawn | Production board-scoped holding and tracked children (`research/tb-keeper-answer-2026-10-05.md:13`; `research/INVENTORY-IVANS.md:51,59–66`) | Board ledger/CAS and current daemon constraints; not a board-free unified host |
| a2a | Durable mailbox, identity lease, doorbell/pull and explicit agent posting (`research/INVENTORY-OURS.md:27–30,139–147`) | Body-as-tool-output boundary; no automatic stdout export or safe PTY paste inferred |
| rwh + worker-jail | Live bounded remote modes; local jailed tools and reviewed patch output (`research/INVENTORY-OURS.md:39–55,62–65`) | Explicit guards; no restart continuity; current standalone driver/auth semantics |
| mandates / curator-trust | Mandate test-key prototype; trust policy design (`research/INVENTORY-OURS.md:73–78`; `research/INVENTORY-IVANS.md:27,84–85`) | Real owner presence/enrollment and session-control scopes are prerequisites, not shipped capabilities |
| keeper / host / bridge / Playbook | Useful specifications and proposed seams (`research/INVENTORY-IVANS.md:26–32,96`; C:614) | New build/adoption work; schemas and qualification required before advertising |

## 2. Module crosswalk: A ↔ B

Classification is about architecture, not implementation maturity. A row may be compatible while still failing the completeness review above. H/C/F are the exact local diff paths defined in §1.

| A module | B counterpart | Relation | Evidence and implication |
|---|---|---|---|
| M1 Session manager | agent-session-host supervisor + holder + registry + restart | Compatible | A `vision/VISION.md:62,108–112`; H:628,645–656,813–831. Same execution-custody responsibility; B adds controller epochs, generations and leases. A's `ax start` intake needs agreement with hosted r6, not a new ax dependency. |
| M2 Context manager | Host harness-adapter packages + event journal + export/seed lifecycle | Compatible | A `vision/VISION.md:63,114–125`; H:629,729–744,762–788. A adds a useful named content API; B keeps custody minimal and journal under the supervisor. Standalone M2 service is not needed. |
| M3 Context bridge | Public separate agent-session-bridge | Same | A `vision/VISION.md:64,127–132`; H:630–632; C:618–626. Central carrier seam, no producer native endpoints. A's C4 deployment does not reflect its prose. |
| M3.x plugin ABI | Producer/consumer bindings | Only-in-A | A `vision/VISION.md:128–130` chooses long-lived child-process JSONL. C:628–663 defines semantics but does not specify the wire/process ABI. B's host adapters are another extension axis, not these plugins. |
| Matrix/a2a provider | Matrix doorbell binding / later signed input | Conflicting | A `vision/VISION.md:241,244` and `matrix-message-injection.puml:24–29`; C:643,840–841; H:894,918. A favors Matrix first with body injection; B excludes unsigned bodies and favors XMPP product delivery. |
| Board-free goal/Ralph provider | No equivalent board-free authority contract yet | Only-in-A | A `vision/VISION.md:52,134–139`; H:880–883 explicitly keeps boardless r6 refused and plain park open; C:626 keeps workflow truth elsewhere. Preserve this requirement via a new capability, not by weakening r6. |
| Terminal/attach provider | Authenticated holder with human raw-terminal lease | Compatible | A `vision/VISION.md:65,110`; H:715,723–728. Human attach is supported conceptually; B states exclusivity and raw capability limits missing in A. |
| M4 thin launcher | Curator run entrypoint + exact-plan receiver | Compatible | A `vision/VISION.md:66,89–93`; H:859–864,878–884. Both prohibit host recomposition/flag reconstruction. `swarm launch` can be a wrapper, but compose-only/board-free/duplex modes require new negotiated contracts. |
| Composer + S6 environment/skills | curator-run + agents-management + environment manager | Compatible | A `vision/VISION.md:94–106,153,227,258`; H:839–850,860,863. One native grammar construction site; target host resolution must return its accepted pin. |
| Permission defaults | Hosted operator permission policy | Conflicting | A `vision/VISION.md:93,251`, curator advice `research/curator-advice-2026-10-05.md:43`; H:851–853. A native-by-default/tracked-yolo refusal versus B yolo-by-default/refusal removed for hosted. Explicit owner/protocol amendment needed. |
| M5 Trust | curator-trust + mandates, key lifecycle | Compatible | A `vision/VISION.md:67,131–143`; H:632,659–701,791–811; C:665–742,810–834. Shared primitives; B is much more explicit about assurance, revocation, presence and exact bytes. |
| M6 rwh + worker-jail | Remote vertical / constrained execution policy | Only-in-A | A `vision/VISION.md:68,84,253`; F:14 names M4 remote milestone but supplies no equivalent rwh/jail/project binding. B mode S requirements are compatible goals, not proof that worker-jail meets the whole guarantee. |
| S1 model router | Model/effort selected by launch tooling | Compatible | A `vision/VISION.md:148,204`; H:860,855. Both leave native launch knowledge in agents-management; B does not specify A's standalone route API. |
| S2 network profiles | Process-owner network policy | Compatible | A `vision/VISION.md:149`; H:864. A's explicit resolver/probe can supply it; enforcement and resume rechecks belong at the execution owner. |
| S3 limits / B6 | Supervisor scheduling and bounded bridge resources | Compatible | A `vision/VISION.md:150,166,212`; H:648,780; C:669,723–732. A adds host-wide provider/validation FIFO; bridge parser/replay/emergency budgets are distinct and must not be collapsed into that semaphore. |
| S4 product/project registry | keeper registered roots | Compatible | A `vision/VISION.md:74–84,151`; H:865–866. Keeper supervision matches. A's product-space taxonomy and versioned project/standing-role binding still need a concrete schema. |
| S5 a2a chat structure | Carrier-neutral producers + coordination swarm | Compatible | A `vision/VISION.md:152`; H:870–876; C:645–663. Membership, identity leases and room ensure remain carrier facilities, not application grants. |
| S7 ops bridges | OS service manager + login-shell resume bridge | Compatible | A `vision/VISION.md:69,260`; H:823–831 and H:401–446. Distinguish OS daemon restart, host reconciliation and registry restore; avoid two automatic restart owners. |
| B1 task store + goal ledger | Board facade's workflow truth | Compatible | A `vision/VISION.md:161,168–171,209`; H:867–869; F:26–30. Both retain board truth in direction; A's goal/provenance/transaction records need the missing revision contracts. |
| B2 flow configuration/engine | Board/playbook authority retained outside host | Compatible | A `vision/VISION.md:22–30,162,173–177`; H:867; F:26. B preserves ownership but does not redesign flow configuration in this package. A's six-part decomposition is additional detail, not evidence of B approval. |
| B3 role router | Board/keeper launch clients, role profiles | Compatible | A `vision/VISION.md:32,163,197–200`; H:860,865,867–868. Shared profile selection; exact per-task profile pin and standing-assignment policy are detailed only in A. |
| B4 spawn facade | Board RUN lifecycle + typed directives to host | Compatible | A `vision/VISION.md:164,202–204`; H:863,867–869; F:26–30. Both remove process ownership from board. Durable spawn intent/RUN reconciliation remains to be specified. |
| B5 board goal binding | Board adapter goal directives and acknowledgments | Compatible | A `vision/VISION.md:31,165,206–209`; H:732,815–818,867–869; F:26. Delivery by stdin can converge; provider-owned board goal acceptance cannot. |
| New platform services in v1.1 | Some restart/version services; no full corresponding service map | Only-in-A | A `vision/VISION.md:36–43`; H:813–855 covers binary/version/restart discipline, but supplied B does not map remote-board/evidence/resource/CI services. These need explicit external dependencies. |
| Assurance mode T/S + native RC policy | No named equivalent in A | Only-in-B | H:659–680,745–758; C:734–773. Add to A's launch/session policy. Same-UID tokens and framing cannot be labeled mode S. |
| Read-only model envelope verifier | M5 verification is host/library-level only | Only-in-B | C:786–808; A `vision/VISION.md:142–143`. B additionally defines caller-scoped evidence reads; optional model use is not enforcement. |
| Journal projections / audience egress / staged receipts | A generic observe/output/tail | Only-in-B | H:762–788; C:775–834. A output forwarding lacks default projection/read scope, audience policy and endpoint-vs-transport evidence. |
| Coexistence/cutover/rollback facade | A fork migration outline | Compatible | A `vision/VISION.md:35,214–217`; H:633–641; F:10–22,34–44. B supplies sticky backend routing, no fallback, absence proof and rollback-reader gates; A's roadmap must preserve them. |

## 3. Conflicts requiring Alexis + Ivan decisions

These are recommendations, not new operator decisions. Resolve them jointly and record the accepted contract revision and responsible owner. No answer is needed to finish this review.

| Decision | A position and evidence | B position and evidence | Recommendation |
|---|---|---|---|
| **D-R1: permission default and tracked yolo** | Native default; yolo waits for a versioned ax capability (`vision/VISION.md:93,251`; `research/curator-advice-2026-10-05.md:43`). | Hosted yolo default unless configured; explicit flag wins; tracked refusal removed (H:851–853). | Do not resolve by choosing whichever document is newer. Obtain Alexis/Ivan plus launcher owner's explicit adopted amendment. Until then retain current native/refusal behavior. If yolo is chosen for a negotiated hosted capability, show effective posture in the plan/receipt, keep deny lists and independent admission, and do not imply yolo makes framing safe. |
| **D-R2: unsigned peer bodies and stdin authority** | Inject framed peer/unsigned content (`vision/VISION.md:131,244`; `matrix-message-injection.puml:27–29`), despite current a2a pull boundary (`research/INVENTORY-OURS.md:139–147`). | Unsigned bodies never reach session/guard; signed peers remain data; mode T excludes native effects (C:643,678–684,738–742). | Adopt B as the default: metadata doorbell/quarantine for unsigned arrivals, operator-enrolled exact-byte signed authoritative input, signed coordination as data. A weaker data-delivery mode is an explicit owner exception with named exclusions. Never sell framing as isolation. |
| **D-R3: entrypoint, board-free pilot and “ax” dependency** | One path for all agents including board-free keepers; `swarm launch` → compose-only → `ax start --launch-plan` (`vision/VISION.md:49,66,89–92,240,252`). | Curator remains entrypoint; existing hosted r6 is board-primary and refuses boardless/new modes absent negotiation (H:859,878–884). Actual ax is early/optional (`research/tb-keeper-answer-2026-10-05.md:13`). | Use `curator run` as canonical entrypoint and host plan-intake contract; keep `swarm launch` optional sugar. Freeze a distinct board-free/structured capability with its own plain park/handoff and duplex channel, without claiming r6 or requiring the ax implementation. Keep board-primary compatibility separately qualified. |
| **D-R4: goal truth, delivery and multiple standing assignments** | v1.1 says board authors goal; M2 stores active/done and provider receives generic set/clear; B5 maps outcomes to transitions (`vision/VISION.md:31,135–139,207–209,248`). | Goals stay with integration owner; board owns CAS, RUN lifecycle/acceptance/context selection (H:732,867–869; F:26). | Ratify board authority as already advised; distinguish immutable board goal revision from delivery progress. Provider clear is an outcome proposal, not acceptance. Add separate board-free goal ledger and explicit standing-session concurrency/slots; do not force board-goal-v2 into one mutable provider goal. |
| **D-R5: native resume, rebuild and harness upgrades** | Preserve by same runtime/home/profile pin; otherwise framed seed; drift default refusal (`vision/VISION.md:111,123–125`). | Preserve-TUI and rebuild-structured are separately negotiated; journal H/linkage/fidelity; optimistic binary updates and eligible last-known-good fallback (H:708–744,835–850). | Keep profile/context drift refusal and separate runtime version policy. Record both identities; a new binary may be allowed only by qualified resume probes/posture. Make continuity and transport separate axes, default to no unsupported conversion, and state bounded rebuild fidelity. Freeze native mutable-state compatibility before enabling fallback. |
| **D-R6: carrier implementation order and privacy target** | Matrix first because a2a is live (`vision/VISION.md:241`; owner `00-owner-concept.md:19–25,33`). | XMPP first product carrier candidate; Matrix doorbell-first, signed-owner bindings open; E2E protocol/device lifecycle unfrozen (H:894,918; C:836–845). | Qualify a local/signed carrier-independent core and Matrix doorbell baseline first. If the first product must promise E2E, fund/freeze the XMPP client/protocol/device lifecycle as a separate prerequisite. Do not infer Matrix membership is app authority or that the local pilot proves E2E. |
| **D-R7: physical process and extension boundaries** | M2 library inside holder; M3 separate JSONL plugin host; combined C4 container; one process per provider (`vision/VISION.md:63–65,128`; `diagrams/c4/model/02-systems.dsl:9–22`). | Host owns supervisor/adapters/journal; holder is minimal; bridge separate; transport plugin process form not frozen (H:628–656; C:628–663). | Use one agent-session-host codebase with Context Engine as internal package, minimal holders, and separate bridge. Keep carrier plugins and workflow integrations distinct from harness adapters. Qualify long-lived JSONL for carriers only; scope instances to security/credential domains. No separate content daemon or generic universal plugin abstraction is needed now. |
| **D-R8: extraction disposition, sequencing and approval evidence** | Adapt host core; flow seam/S3/spawn migration in fork; board flows Phase 4 (`vision/VISION.md:35,214–217,224,260–264`). | Hybrid preferred but mandatory SH1 replacement vs as-is capsule still open; explicit operator go, sticky legacy routing, no board-main cutover before agreed window (H:633–641,911,920; F:10–22,34–44). | Record M0/SH1 amendment and unchanged parity obligations first. Keep legacy production routes sticky. Build host/board compatibility early; build externally configurable flows last. State whether earlier independent S3/flow work is within the accepted extraction scope. Treat October 19 as an earliest window constraint, never proof of safety or automatic authorization. |

Two apparent conflicts need no new architecture fork: tool-home only is supported by Curator's hard HOME contract (`research/curator-advice-2026-10-05.md:8–31`), while empty remote HOME is executor isolation. Also, the initial owner says no board in the first platform (`00-owner-concept.md:3,36`); A still builds flow work last (`vision/VISION.md:264`). Defining board client contracts now is compatible. A's claim of a later owner direction (`vision/VISION.md:8`) is not independently evidenced in this snapshot, so this review does not treat it as permission to advance board implementation into Phase 0.

## 4. Postable review comments on Ivan's PRs

Anchors below are actual proposed new-file lines calculated from unified-diff hunk positions. The line following each comment gives its exact local diff evidence. Comments address remaining gaps or necessary convergence, not claims that B's stated mitigations are already missing.

### agent-session-host PR #11 (10 comments)

1. **relux-works/agent-session-host#11 spec/session-host.md:108 —** Please freeze whether the transactional journal is owned by the supervisor or a Context Engine package before implementation. The parallel vision places it inside each holder; that conflicts with this ownership and with the holder's no-goal/no-board rule. I recommend one host-owned journal and typed context APIs, with holders only responsible for custody and bounded spooling.

   Local anchor: `r191/agent-session-host-PR11.diff:648–655` (§A2).

2. **relux-works/agent-session-host#11 spec/session-host.md:152 —** Please align “persist ... atomically” with bridge PR #1's bridge-local admission transaction plus idempotent durable host enqueue. Name which store owns each record and require the host acknowledgment before returning acceptance. Otherwise two implementations can infer an impossible cross-process transaction or acknowledge a command that never reached the queue.

   Local anchor: `r191/agent-session-host-PR11.diff:692`; compare `r191/agent-session-bridge-PR1.diff:676,900`.

3. **relux-works/agent-session-host#11 spec/session-host.md:111 —** Please specify who atomically checks controller epoch, execution generation and input lease with the native write. The dispatch recheck in §A3 and authenticated holder write in §A2 must have one final fence; a stale controller must not pass a supervisor check and then write after replacement. Add the race where reconciliation advances the epoch between validation and dispatch.

   Local anchor: `r191/agent-session-host-PR11.diff:651`; relevant requirements at diff lines 692,718.

4. **relux-works/agent-session-host#11 spec/session-host.md:191 —** The rebuild lifecycle is sound, but please define retirement/rollback eligibility between handoff commit and new linkage. Does the committed-H record itself fence the old holder, including direct writes from a stale controller? State the durable owner at each stage and include crash-after-launch-before-seed and seed-rejected cases, as well as uncertain seed acknowledgment.

   Local anchor: `r191/agent-session-host-PR11.diff:731,739–744` (§A4).

5. **relux-works/agent-session-host#11 spec/session-host.md:195 —** Please make the first handoff capability explicitly unavailable until its versioned schema, supported fidelity, audience/provenance and secret-free projection rules are accepted. The swarm handoff currently carries summary/events/config/dirty-patch references without item-level policy. A package signature must not promote historical peer data into new instructions or prove a recipient may read it.

   Local anchor: `r191/agent-session-host-PR11.diff:735`; compare `vision/VISION.md:121–125`.

6. **relux-works/agent-session-host#11 spec/session-host.md:256 —** The 0600 host-key choice is acknowledged, but please bind its permitted assurance mode to the admitted session. A same-user harness may read a 0600 file; an inherited descriptor alone does not establish replacement-supervisor identity. Keep survivor re-adoption unadvertised until A-Q5's protected installation identity/broker and replay-resistant challenge are qualified, without reopening the accepted key-storage decision.

   Local anchor: `r191/agent-session-host-PR11.diff:796`; dependencies at diff lines 651–654,811,915.

7. **relux-works/agent-session-host#11 spec/session-host.md:276 —** Please include goal revision/slot/run identity in the observed ready signal, not only handoff_ref. A late acknowledgment for an older park or goal must not satisfy this restart. Specify the board CAS failure path and how delivery resumes only after the committed revision is observed; the goal provider may report progress but cannot manufacture readiness.

   Local anchor: `r191/agent-session-host-PR11.diff:816–821` (§A7).

8. **relux-works/agent-session-host#11 spec/session-host.md:311 —** This changes the effective permission default and removes tracked-yolo refusal, while the swarm vision and curator advice still require native/default refusal pending a versioned capability. Please link the adopted launcher/protocol amendment and capability/schema version, including precedence and deny-list preservation, before consumers follow this rule. The bridge gate does not compensate for native tool effects under mode T.

   Local anchor: `r191/agent-session-host-PR11.diff:851–853`; compare `vision/VISION.md:93,251` and `research/curator-advice-2026-10-05.md:43`.

9. **relux-works/agent-session-host#11 spec/session-host.md:320 —** Please split environment profile content from launch-owned bridge binding/policy. “Profiles select ... bridge bindings” can be read as authorizing project package bytes to choose endpoints, audiences or credentials. Put resolved bindings and their authorized digest in the launch intent/plan metadata, apply operator ceilings and recheck at resume; do not extend the closed environment fragment implicitly.

   Local anchor: `r191/agent-session-host-PR11.diff:860–864`; compare `vision/VISION.md:94–106` and `research/curator-advice-2026-10-05.md:56`.

10. **relux-works/agent-session-host#11 spec/session-host.md:340 —** Retaining board-primary r6 is correct. Please add an explicit follow-up contract/owner for board-free keepers and goals rather than allowing the swarm launcher to imply they already work through r6. Freeze plain park readiness, typed duplex hosting, continuity/assurance combinations and goal ownership before advertising this new capability; ax remains optional, not the required implementation of plan intake.

    Local anchor: `r191/agent-session-host-PR11.diff:880–884`; compare `vision/VISION.md:89–92,260–262`.

### agent-session-bridge PR #1 (9 comments)

1. **relux-works/agent-session-bridge#1 docs/architecture.md:23 —** Please add the transport-plugin ABI gate: process scope, version negotiation, bounded frames, secret broker access, correlation, crash/cursor recovery and sanitized inherited environment/descriptors. The swarm proposal chooses long-lived JSONL processes, but that is distinct from the host's harness-adapter packages. No plugin should obtain another binding's authority by naming its ID in a payload.

   Local anchor: `r191/agent-session-bridge-PR1.diff:634–641`; compare `vision/VISION.md:128–132`.

2. **relux-works/agent-session-bridge#1 docs/architecture.md:32 —** This conflicts directly with the swarm design's unsigned-peer stdin branch. Please mark it as a joint owner decision and state whether any weaker data-only binding is intentionally supported. Recommend keeping quarantine/metadata-only delivery as the default; do not turn invalid signatures into “untrusted but deliverable” content or let a carrier's login substitute for application authority.

   Local anchor: `r191/agent-session-bridge-PR1.diff:643`; compare `diagrams/plantuml/sequence/matrix-message-injection.puml:27–29`.

3. **relux-works/agent-session-bridge#1 docs/architecture.md:47 —** Please separate the security dedup key from binding revision and derivative metadata. This tuple includes binding revision, while §3.3 says rewraps/rotation preserve one origin identity. Rebinding the same event must not make it new work. Define the stable principal/origin key, bind changed bytes to conflict, and keep revisions/derivatives as evidence linked to that one command.

   Local anchor: `r191/agent-session-bridge-PR1.diff:658–661,704–706`; corresponding threat-model tuple at diff line 955.

4. **relux-works/agent-session-bridge#1 docs/architecture.md:65 —** The bridge-local commit plus durable idempotent host enqueue is a good recovery contract. Please state the authority of that enqueue API: the host must authenticate the gate and revalidate target, generation and evidence, or enforce an unforgeable scoped admission handle. A caller-supplied command/evidence object cannot self-certify admission. Include forged enqueue and stale binding/controller negative traces.

   Local anchor: `r191/agent-session-bridge-PR1.diff:676`; compare host-side enforcement at `r191/agent-session-host-PR11.diff:235–240,682–696`.

5. **relux-works/agent-session-bridge#1 docs/architecture.md:80 —** Please define safe behavior for an ordered-class gap whose missing command is a revoked approval or fenced execution. An “explicit recorded gap” should not authorize applying the later command to a different native interaction. Keep ordering/gap policy separate from the exact live request/generation checks; qualification should include reverse delivery across restart and permission revision changes.

   Local anchor: `r191/agent-session-bridge-PR1.diff:691–696`; host interaction rules at `r191/agent-session-host-PR11.diff:718–722`.

6. **relux-works/agent-session-bridge#1 docs/architecture.md:119 —** Please define the emergency route's evidence and authority when the audit disk is full. “Admits no commands” must distinguish positive work admission from typed halt/fence operations, which still mutate host state. Identify the bounded independent control resource, authenticate its caller, retain the strongest available evidence, and prove it cannot clear fences or widen grants under saturation.

   Local anchor: `r191/agent-session-bridge-PR1.diff:729–730`; host bounds remain open at `r191/agent-session-host-PR11.diff:780`.

7. **relux-works/agent-session-bridge#1 docs/architecture.md:150 —** “Otherwise the mode T limitation applies explicitly to that session” can imply falling back from requested S after RC exclusion fails. §4 and host §A3 correctly require refusal/park and separately authorized re-admission for S→T. Please use that exact rule here: a failed S qualification never becomes a T session merely by adding a limitation label.

   Local anchor: `r191/agent-session-bridge-PR1.diff:761`; controlling rules at diff line 740 and `r191/agent-session-host-PR11.diff:667,747`.

8. **relux-works/agent-session-bridge#1 docs/architecture.md:171 —** Please clarify that a consumer's render transform is covered by the checked proposal identity. If the consumer edits markdown, escapes terminal/HTML, expands a reference or adds a quote after approval, the transmitted plaintext may no longer be the approved bytes. Freeze the carrier-visible representation before release or create a new authorized derivative; audience/policy rechecks still apply at actual delivery.

   Local anchor: `r191/agent-session-bridge-PR1.diff:782–784` (§5).

9. **relux-works/agent-session-bridge#1 docs/architecture.md:230 —** Please turn XMPP protocol/client/group-device lifecycle into an explicit capability gate and separate it from the Matrix local pilot. The carrier-neutral core and signed application identity can be qualified without promising E2E. Which binding can advertise E2E depends on its accepted endpoint/key/rotation/revocation matrix, not the carrier name or the existence of pairing.

   Local anchor: `r191/agent-session-bridge-PR1.diff:840–845`; ordering decision at diff line 875.

### skill-project-management-session-split PR #1 (5 comments)

1. **relux-works/skill-project-management-session-split#1 docs/session-split/README.md:9 —** Please map each milestone to a named capability and proof boundary. In particular, the portable structured rebuild pilot can proceed independently of survivor re-adoption, while native custody and board-primary compatibility have separate gates. State which pilot is first and do not price all three as the same vertical.

   Local anchor: `r191/session-split-PR1.diff:15`; host separations at `r191/agent-session-host-PR11.diff:734–735,911–912`.

2. **relux-works/skill-project-management-session-split#1 docs/session-split/README.md:21 —** Please record the goal/delivery split precisely: board retains revision/slot/CAS/acceptance; bridge/provider retains delivery receipts and nudge scheduling only. A provider's “done” cannot clear the board goal until the board accepts its transition. Include refused/stale outcome and multiple goals assigned to one standing session in facade conformance.

   Local anchor: `r191/session-split-PR1.diff:27`; compare `vision/VISION.md:207–209`.

3. **relux-works/skill-project-management-session-split#1 docs/session-split/README.md:25 —** Please distinguish retained legacy mutable records, read-only imported history and new experimental records. “Old records are preserved read-only” must not freeze the live legacy goal/RUN ledger while legacy sessions continue. Pin one backend writer per live record; history copies can be read-only, and custody/schema transfer requires its own transaction.

   Local anchor: `r191/session-split-PR1.diff:31`; sticky legacy routing at diff line 23.

4. **relux-works/skill-project-management-session-split#1 docs/session-split/README.md:29 —** Please make accepted M0/SH1 disposition an implementation-entry gate, not only a merge-back checkbox. Hybrid is preferred but replacement of whole-package SH1 remains open in host PR #11. Name the accepted retained parity fixtures, source inventory and forward-port owners before production extraction starts; design/fixtures can continue under the rule above.

   Local anchor: `r191/session-split-PR1.diff:35`; production extraction rule at diff line 22; host open disposition at `r191/agent-session-host-PR11.diff:635,911`.

5. **relux-works/skill-project-management-session-split#1 docs/session-split/README.md:35 —** Please extend cutover evidence to all record writers and detached consumers, not just the harness process. A stopped holder does not prove a landing/push/goal-CAS or retry owner is absent. Freeze per-session backend routing and schema generations before reopen; rollback must demonstrate that the old reader accepts every retained mutable schema, otherwise remain fenced as the next item requires.

   Local anchor: `r191/session-split-PR1.diff:41–42`; drain obligations at `r191/agent-session-host-PR11.diff:817–822`.

## 5. Merge proposal and next five steps

Adopt one platform architecture with an early legacy compatibility facade and later configurable flows. Do not create a second session host, second native flag composer, or separate generic plugin layer that conflates harness adapters, carriers and workflows.

### Unified module map and names

| Agreed name | Ownership and deployment | Contract boundary / convergence |
|---|---|---|
| **Launcher — `curator run`** | Canonical launch entrypoint; optional `swarm launch` wrapper. Curator-run composes, agents-management alone constructs native grammar. | Versioned LaunchIntent/LaunchPlan; dry run and compose-only; local/remote capability negotiation. Goals and bridge policy remain typed session/launch payloads, outside managed profile text. Execution stays in host/remote executor. A M4 + composer; B launch tooling. |
| **Session Host — `agent-session-host`** | One supervisor per OS security domain; session/execution registry, scheduling, host-enforced admission, control API, restart/reconciliation. | Exact finalized-plan intake, lifecycle/typed-control API, opaque context refs and capability tokens. Preserve hosted-r6 compatibility; add board-free modes separately. `ax` is an optional backend/protocol peer. A M1; B supervisor. |
| **Execution Holder** | Minimal per-execution process owning native subprocess/PTY/framed pipes. No goal semantics, board store, carrier login or root signer. | Authenticated controller epoch, execution generation, input lease, spool acknowledgment and evidence; exclusive human raw-terminal lease. Supervisor death permits no new writes until qualified reconciliation. B holder; resolves A's implicit process split. |
| **Context Engine** | Internal host package containing harness adapters, event normalizer, journal, snapshot/export/seed/native-resume capabilities. One host-owned content store. | Typed input/observation, live interactions, context usage, HandoffPackage at H, execution linkage, audience/provenance filtering. M2 is a named content responsibility, not a new daemon or independent writer. |
| **Session Bridge — `agent-session-bridge`** | Separate service hosting carrier producers/consumers and caller-scoped verifier/tails. Applies shared trust primitives; host authenticates its enqueue/control requests. | Binding/projection protocol; bridge-local durable admission and idempotent host enqueue; audience-checked outbox and staged receipts. Versioned JSONL carrier ABI if approved. A M3; B bridge. |
| **Trust services — `curator-trust` + mandates** | Identity/pins, grants, revocation snapshots, presence and scoped signer/secret brokers. No new cryptographic trust library. | Exact-byte envelope verification, action/resource/audience grants, replay rules and mode evidence; deployment-specific revocation and same-UID limits explicit. A M5; B trust. |
| **Goal Loop** | Board-free goal authority as a narrow service/host package; delivery scheduler exposed through bridge. Board binding has its own revision references. | Agent-authored board-free set/clear/CAS and bounded nudges; board-owned goals are published immutable revisions with delivery/outcome proposals. Tail authority derives from the authenticated caller. No provider-promoted operator authority. |
| **Remote Executor — rwh + worker-jail** | Target execution owner; authenticated launch intent and actual accepted plan identity; local jail is the tool-effect boundary. | Versioned project binding, protected credential lookup, exact base SHA, bounded tool/I/O relay and reviewed outputs. Validate mode S separately; neither remote hosting nor a jail label alone proves it. A M6; B remote milestone. |
| **Registry / Keeper** | Registry service and deterministic keeper supervision client; meta/product/project keeper are agent roles. OS service manager restarts the daemon; keeper requests eligible session restoration. | Versioned product/project/host/standing-role bindings; supervision matrix; reboot/auth readiness and full reporting. Avoid duplicate restart controllers. A S4/S7; B keeper/OS resume bridge. |
| **Routing, environment, network and capacity services** | Model router, Curator environment/skill registry, process-enforced network policy, host capacity/validation FIFO. | Pins and plan metadata; acquired/renewed/transferred leases. Keep bridge admission/storage/guard budgets distinct from provider slots. Name CI/evidence/remote-board dependencies explicitly. A S1–S3/S5–S7; B environmental/control dependencies. |
| **Board — B1–B6 behind compatibility facade** | Workflow/goal/RUN truth stays in board; B2 configured flows arrive later. B3 resolves exact role-profile pins; B4 calls Launcher; B5 sends directives via Bridge; B6 consumes Capacity. | Immutable kernel/domain safety gates below Playbook; transactional transition/action intents, goal revision CAS, exact acknowledgment and record compatibility. Sticky legacy versus experimental backend, one writer, no fallback. A board map; B facade and fork gates. |

The dependency direction is: board/keeper/CLI clients → Launcher or Bridge → host typed APIs → Context Engine/adapters → holder → native execution. Trust is consulted at admission and dispatch; all content export consults audience policy. Journal projections flow back to authorized bridge consumers. The goal loop requests typed operations; it never writes M2's store or a native descriptor directly. Remote execution owns its enforcement and returns evidence to the same logical-session APIs. No host package imports the board or a carrier. Ordinary request/response callbacks are acceptable; shared writable stores and circular code dependencies are not.

### Next five steps

1. **Record the joint decisions and implementation scope.** Alexis + Ivan, with launcher/host/board/trust owners, resolve D-R1–D-R8, M0/SH1 disposition, first pilot, exact capability gates and preserved parity obligations. Attach accepted source SHAs and the missing PR #8/#9/normative protocol references. Keep the explicit production-extraction go separate from this review and from the calendar window (F:22,35,41). Result: one adopted decision ledger, not two conflicting “decided” documents.

2. **Freeze the smallest contract bundle.** Publish schemas and negative fixtures for LaunchIntent/Plan/admission, BridgeBinding+Envelope+enqueue/receipts, ProjectBinding, typed interactions/leases, GoalRevision/delivery outcomes and bounded HandoffPackage. Freeze continuity/transport/assurance combinations and plain-session park. Include changed-ID bytes, wrong target, forged plugin author, stale controller/approval, disk-full, old snapshot, audience change and seed uncertainty. Disable unsupported capabilities rather than filling gaps with inferred semantics.

3. **Repair A and align B's remaining wording.** Split C4 process boundaries; route plugin calls through Bridge; add mandatory kernel predicates, lifecycle fences and termination of refused restore branches; fix version/role-pin/launch metadata fields. Reconcile bridge-vs-host admission transaction, replay key versus binding revisions, mode-S refusal language, consumer render identity and facade record mutability. Validate the resolved Playbook only after its pinned base/validator are available. These documentation changes are follow-up work, not changes made by this review.

4. **Build and qualify one isolated vertical after the recorded go.** In the private fork, explicitly route a new board-free structured session through the canonical composer/host/context/bridge path with one harness and one declared OS/security mode. Prove typed interaction handling, durable admission/outbox, secret-free authorized seed and controlled restart; use Matrix doorbells or a test producer initially. Qualify survivor re-adoption, other harnesses, remote execution and E2E separately. Keep existing Phase-0 production routes sticky; the board facade retains goal/RUN/notice parity before any board cutover.

5. **Cut over only the proven consumers, with rollback and observation.** Name forward-port owners, sync live main, stage paired schemas/binaries, prove all writer absence or authenticated transfer, retain admission fences through reconciliation, and demonstrate rollback-reader compatibility. Apply the agreed earliest window plus explicit release authorization; do not retire unqualified legacy paths. Observe unknown delivery, stalled approvals, replay gaps, goal/CAS mismatch, lease leaks and restart outcomes for an evidence-based duration. Add the default-flow seam and new dev/design workflows last, under the mandatory kernel guards (F:34–44).

### Verification and remaining limits

Read-only project checks passed: `structurizr-cli validate -workspace diagrams/c4/workspace.dsl` and `plantuml -checkonly diagrams/plantuml/sequence/*.puml`. All 13 supplied PNGs contain embedded PlantUML matching their checked-in sequence or exported C4 sources. That verifies render/source correspondence, not semantic correctness; no new renders were written. The Playbook parses as JSON, but its own description says its validator is not shipped, and the referenced base/spec is absent. No runtime tests are available in this documentation-only snapshot. Section/line citations and new-side PR anchors were checked against the supplied files. Owner choices, absent normative contracts and runtime qualification remain open; this review authorizes no extraction, deployment or production cutover.
