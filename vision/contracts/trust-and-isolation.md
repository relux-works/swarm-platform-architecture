# Contract: trust and isolation — identities, keys, grants, workplaces, channels, credentials

Status: VISION v1.3 contract draft (2026-10-08). Collects the owners' call of 2026-10-07 and the design sessions of 2026-10-06…08. Russian narrative with the same content: wiki `session-host/architecture.ru.md` §7. Diagrams: `diagrams/plantuml/sequence/` (`keeper-sign`, `grant-issue-and-check`, `action-namespace-registration`, `delegated-action-handler`, `mailbox-delivery`, `spawn-with-user`, `keeper-team-start`, `external-agent-onboarding`, `remote-workplace-attach`). Status marks: **decided** (owners), **proposed** (this draft), **open**.

## 1. Principles

1. **An agent never holds a secret.** It asks a privileged neighbour to do something with the secret. What an agent cannot do physically, a prompt injection cannot make it do.
2. **Trust never rests on the transport.** Pipes are encrypted as hygiene; authority is only a signature over exact bytes plus a grant. Where a command came from does not matter.
3. **The kernel is the sandbox.** One OS user per autonomous agent; the kernel's user isolation, not a container or a prompt, is the boundary. (decided)
4. **Checks happen where the action happens**, never in the requester. One verification library everywhere.
5. **No free text in the authority layer.** Actions are registered names with schemas; free text reaches agents only as `data` or a doorbell.

## 2. Identities and the key keeper

- **Identity** = a stable derivation path plus its public key, never an OS path or UID: `purpose'/product'/project'/agent'` (hardened derivation, BIP-32/SLIP-0010; a child key reveals nothing about its siblings). (decided)
- **Root.** The keeper publishes the public root; the owner confirms it once at installation. Each agent identity is a public key plus the root's signature "descendant N". Anyone verifies the chain offline.
- **Keeper** (privileged daemon, the only holder of the master secret in Secure Enclave / TPM / DPAPI-CNG where available; on macOS a LaunchDaemon with the System keychain). Unix socket API: `sign(bytes)`, `decrypt(blob)`, `pubkey(identity)`, `register(uid, path)` (dispatcher only), `revoke(identity)` (owner act or dispatcher at retire). The kernel reports the caller's UID (`LOCAL_PEERCRED` / `SO_PEERCRED`); the keeper keeps a mutable map *UID → path* and answers only with that identity's key. No API returns a private key; key pairs are never placed in an agent's keychain.
- **Decrypt** returns plaintext only to the calling process, audited and rate-limited. The keeper protects the key, not the plaintext: packages are addressed only to whoever must read them and carry nothing extra.
- **Lifecycle.** Deleting the OS user stops the agent; re-registering the same path on another machine with the same master secret restores the identity (migration). Retiring = a root-signed revocation record.
- **External identities** (other organisations, remote workers) bring their own key pair: a self-signed certificate is verified, the public key is pinned, and the root signs an admission record "external key K admitted with role R". Both kinds live in one registry under the same checks.
- **Risk.** Master-secret compromise compromises everyone: the keeper stays minimal, privileged, audited.

## 3. Grants

- **Record.** `grant/1 {issuer, subject (key or role), actions[], targets[], conditions{lang, …}, delegable{depth}, parent?, expires_at, sig}`. Role bindings are separate signed records, so a grant to a role covers whoever holds it; playbook role rights are grants to roles.
- **Delegation with attenuation.** A requester may grant at most a subset of what it holds and of what is marked delegable: subset of actions and targets, expiry not later, depth not deeper; `parent` links the chain to the root. The dispatcher refuses a spawn whose requested child grants exceed the requester's delegable grants. Inspiration: SPKI/SDSI, Macaroons, UCAN, Biscuit (Biscuit's Datalog and offline verification are a candidate implementation). (proposed)
- **Conditions and the policy language.** `conditions.lang = caveats/v1` today (time windows, counters, operator confirmation, target lists); `datalog/v1` or similar later. One library with pluggable evaluators; envelopes carry only grant references, so a policy language never changes wire formats. (proposed)
- **Checking.** The task core checks role grants when it moves a task or accepts a result; the dispatcher checks spawn grants; the broker checks "may write to this agent" before delivery; the bridge checks the audience on the way out. An orchestrator asks; it never judges.
- **Issuing and syncing.** Grants are managed in the owner's client app and synced through a signed trust gateway into the registry; services subscribe to revocation snapshots and re-admit at dispatch. Where the registry lives (git journal, Matrix state, a service, a hybrid) is **open**.

## 4. The action vocabulary and handlers

- **Vocabulary.** A registered set of namespaces, each with argument schemas and a handler: platform base `session.*`, `goal.*`, `board.*`, `user.*`, `spawn.*`, `post`, `inbox`, `terminal.raw`; later e.g. `github-runner.*`. Targets are typed resource ids (`session:…`, `host:mini/runners/x`, rooms, board elements); wildcards only in grants, commands name a concrete target.
- **Registration** (three signed records):
  1. `handler-manifest/1 {handler identity, actions{name: args schema}, target form, effects: reversible|irreversible, sig}` published by the handler;
  2. `action-namespace/1 {namespace, handler, manifest_sha256, hosts[], grantable_by[], issued_by (chain), expires_at, sig}` issued by the owner or by an agent holding `registry.actions.register` — attenuated, e.g. only inside `ops.*`; the same name again only with the same handler or a root-signed replacement; removal is a revocation;
  3. grants and commands name the registered action. A grant on an unregistered action is refused at issue; the gate validates arguments against the manifest.
- **Handlers.** A *process* handler (deterministic helper) for OS-level and irreversible effects re-verifies the chain itself, executes exactly one registered operation, audits and signs its receipt. An *agent* handler (e.g. an admin orchestrator with wide grants) receives a typed `authoritative` item with a verification record, may re-verify, adds judgement, and executes with its own permissions (a narrow sudo rule or the helper); it cannot amplify. `effects: irreversible` hints that a process must handle it.
- **Worked example.** G1: root → Alexis's pinned key, `github-runner.{restart,stop}` over `host:mini/runners/*`, caveats (hours, rate), delegable depth 1. G2: Alexis → his orchestrator, a subset, `parent: G1`. His orchestrator sends `swarm-envelope/2 {action github-runner.restart, args{runner x}, target host:mini/runners/x, grant_refs [G2, G1]}` signed by its keeper. Our gate verifies signature, pin, chain, attenuation, schema, caveats, revocation; the registry names the handler; a receipt returns signed. Sequences `action-namespace-registration`, `delegated-action-handler`.

## 5. Agent workplaces (one OS user per agent)

- **Every autonomous agent** — meta-keeper, keepers, orchestrators, standing specialists, ephemeral workers, remote workers' workplaces — runs as its own OS user. (decided)
- **Creation** by one narrow privileged helper that sudoers admits for the dispatcher (and nothing else); the helper creates the user, home, group, ACL, quotas and firewall rules, and removes them at retire. A system-administrator *capability* is a grant (`user.create`), not an agent.
- **Network.** The kernel firewall per UID (pf `user`, nftables owner match, WFP) admits only the message broker and the egress proxy of the network profile; everything else is dropped and counted. This makes network profiles enforced rather than cooperative.
- **Homes.** Flat (`/Users/agents/<id>`): orchestrator home 0700; worker home 0750 plus an inherited ACL read entry for the parent (macOS `chmod +a "orch allow list,search,read,…,file_inherit,directory_inherit"`, Linux `setfacl -R -m u:orch:rX` and the default ACL). Limits: on Linux the ACL mask follows the file mode (a 0600 file stays unreadable); on macOS the owner can remove the ACL. ACL is a convenience; guaranteed observability comes from the host (journal, transcripts) and from board results and handoff packages.
- **Ephemeral trees.** A "cheap tree copy" abstraction: APFS clone on macOS, `cp --reflink=auto` on Btrfs/XFS (a plain copy on ext4), overlayfs optional; default everywhere `git worktree`, which works out of the box on Debian and Arch. Session logs stay out of git.
- **Stable team.** A project binding declares `team[] {role, identity, standing|ephemeral, max}`; S4 `up` brings standing members back idempotently after a reboot; ephemeral users are created per run and removed at retire.
- **Privilege model.**

| Component | Runs as | Why |
|---|---|---|
| keeper | root (LaunchDaemon / service) | hardware-backed secret; peer-UID signing |
| user/firewall helper | root for one command (sudoers) | users, ACL, pf/nftables rules |
| session host | own unprivileged user | starts holders as agents through the helper |
| bridge and broker | own unprivileged user | holds carrier credentials; peer-UID sockets |
| dispatcher | own unprivileged user | accounting; calls the helper |
| agents | one user each | kernel boundary |
| human administrator | own account | runs nothing of the platform |

## 6. Entry channels and the message path

- **Three entries.** *Root channel*: the operator only, locally — a signed command or a terminal under the exclusive lease (`terminal.raw`); the host writes straight into the PTY. *External channel*: carrier plus broker — the only path for every external party, external orchestrators included; never the root channel. *Join point*: a one-time HTTPS endpoint for introductions (certificates in, credential packages out), never commands; unnecessary when the package travels out of band. (decided)
- **Agents never read the carrier.** The broker (the room member) holds carrier credentials. A provider persists each raw event (append, fsync) *before* advancing its carrier cursor, then hands the bridge an envelope; a replay after a crash is harmless because admission is idempotent per (sender, id).
- **Trust gate**, pure library, no network, no model: canonicalise (JCS) → find the key by `key_id` in the registry snapshot → verify Ed25519 → derive the sender → load `grant_refs` and walk the chain to the root (each link signed by its issuer, subject = next issuer, actions/targets narrowing, expiries nested) → revocation snapshot → time window and replay journal → target binding revision → verdict and an admission record signed by the bridge. Any failure is `reject` with a reason and an audit line.
- **Decision guard.** After the gate, a small local model compares the request with the addressee's grant specification and injection patterns and records `{body hash, sender, grants used, model version, verdict, fingerprint}`; the host rings the doorbell; the agent fetches body plus verification record from the **Mailbox** (`inbox read`, In and Out) and may re-verify. If the guard is unavailable, the answer is no.
- **Who may write In / read Out.** By default only the parent (granted automatically at spawn); everyone else through the broker. The owner, as root of trust, holds every grant. **Proposed.**
- **Encryption.** Signatures over the carrier's own end-to-end encryption; no envelope encryption of our own for now. People use ordinary clients; signatures ride in event metadata. (decided)
- **Federation test.** The owners' two-domain setup (own Matrix servers, machines, regions; shared rooms for shared projects) is the reference test for federation and onboarding after the single-host MVP.

## 7. Remote workplaces

- A remote worker's harness runs on the **donor** machine; on our host it gets a workplace user: SSH by its pinned key (`authorized_keys` with `restrict` and a forced command running the tool executor), firewall per UID, quotas. The connection goes only towards our host and carries only tool execution; tasks and spawns arrive as signed messages through the broker and mailbox; our host never opens connections to, or sends commands into, the donor machine. (decided)
- **Join.** `swarma join <invitation>` generates a key pair and a self-signed certificate, shows the fingerprint, posts it to the join point over HTTPS; we confirm the fingerprint over a second channel (invitation code, voice), pin the key, sign the admission, and return a credential package encrypted to the worker's key (carrier identity, rooms, tokens, our root key, our SSH host-key fingerprint). Our fingerprints are also published in DNS (TXT for the root, SSHFP for the host key, DNSSEC).
- **Remote Bash.** A framed executor protocol over the SSH session: `{id, cmd, cwd, env allowlist, timeout}` → stdout/stderr frames → exit; cancellation; per-request time and output limits; audit of every command; a dropped channel kills the children.
- **Donor protection** (open, assigned to Curator on 2026-10-08): a "remote worker" launch mode disabling every locally-acting tool so that the only capabilities are the remote-tools MCP and the mailbox; yolo marked "nothing can be done on this machine; the remote side is sandboxed"; a donor-side OS user and firewall set up by Curator at first deployment. Curator today has no tool-deny field in profiles (Decision 0014 proposed; only `native|yolo` from 0018) and partial MCP injection; proposed Curator tasks T1–T5. On a foreign machine no launcher setting is a boundary by itself.
- Remote workers use their own provider credentials.

## 8. Provider credentials

- **Facts.** No vendor offers short-lived subscription leases; subscription logins are single-use-rotating refresh-token families, so shared copies self-destruct on concurrent refresh. Vendor terms bind subscriptions to one person and ordinary individual use.
- **Today in Curator.** `claude setup-token` is not used; on macOS each managed home has its own Keychain login; Codex `auth.json` is file-linked with in-place refresh; CIP-0003 is a draft.
- **First implementation (decided posture).** Subscriptions now, tokens architecturally; Claude: one-year `setup-token` in the launch environment (needs the CIP-0003 work); Codex: one shared `auth.json` per account; Muse: an env key (`META_API_KEY` pass-through task filed). Agents hold credentials in this phase (assurance mode T). Credential injection at the egress proxy is research only: providers may flag intercepted traffic.
- **Open.** Bare homes reusing a root (or higher-node) authentication; who owns re-login after a logout (proposal: the host notices and parks, the credential broker runs the vendor's own flow and relays the code to the account owner's phone, the host restarts on the broker's signal).

## 9. Session-host duties added on 2026-10-08

- **Input hygiene across restarts.** Claude Code's queued-prompt records and drafts are restored on `--resume` and a remote-control client may show an old prompt in its input box; tooling that types into panes can leave residue. The host checks for unmatched queued items before parking, shows them to the operator, and after a restart reminds the operator to clear the client input. (decided; today in the relaunch script)
- **Auto-answers.** The wrapper answers harness security prompts only from an allowlist under the parent's `session.approve`; everything else parks and asks a holder of that grant (a parent orchestrator or a human). Every auto-answer is audited.
