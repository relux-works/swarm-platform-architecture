# Contract: provider plugin processes, native interactions and the human terminal

Status: VISION v1.2 contract draft. Fixes A-M4 and A-M7 (JR). The JSONL carrier ABI is qualified for carriers only (D-R7); harness adapters are host packages, not plugins.

## 1. Provider plugin ABI `swarm-plugin/1`

- **Install and pin.** The bridge config names each plugin by executable path + sha256 + version. Installing or changing one needs an operator mandate. The bridge refuses to start a plugin whose digest differs.
- **Handshake.** `hello{abi: "swarm-plugin/1", plugin_version}` → the bridge answers with the negotiated ABI or refuses.
- **Instance scope** follows the credential and security domain, not the provider name: one process per `(provider, credential_domain)`, for example one Matrix process per agent identity.
- **Host-assigned handles.** `bind` gives the plugin an opaque `binding_handle`. A plugin can emit envelopes, cursors and receipts only for handles it holds. The bridge derives `principal` from the handle and the carrier's verified identity; a plugin's `sender` is `claimed_sender` (data).
- **Secrets.** `bind` passes no secret values and no `secret_ref`. The plugin calls `secret.resolve(binding_handle, name)` on the bridge's broker, which checks the binding's grant and returns the value over the plugin's own pipe. Mode T caveat: same-UID, a guardrail.
- **Process hygiene.** Sanitized environment (no `SWARM_SESSION_TOKEN`, no tool-home variables, a dedicated `HOME` and state dir), only fds 0–2 inherited, its own working directory.
- **Limits.** Frame ≤ 256 KiB; ≤ 1000 queued frames per binding; per-binding rate limit; 30 s request timeout; every request carries a `correlation_id`. Over a limit: the frame is refused and counted; repeated overflow restarts the plugin.
- **Lifecycle.** Crash or `health` failure → restart with backoff. On restart the bridge re-binds with the same handles; the plugin resumes from its own durable cursor; the bridge re-sends receipts from its store. Admission is idempotent (`admission-and-delivery.md` §5), so a replay after restart is safe.
- **Logs.** stderr goes to a per-plugin log file, separate from the bridge's audit log; it is never parsed.

## 2. Native interactions (permission prompts, questions)

- The adapter turns a native dialog into `interaction.pending{interaction_id, execution_id, turn_id, kind: permission | question, native_request_digest, options[], expires_at}`. The readiness grammar for this is pinned per admitted harness release (an adapter-version table); herdr's idle fallback and remotely updated manifests are not reused as-is (`research/herdr-study.md`). Unknown screen state parks.
- The bridge posts an ask to the bound out providers. An answer is an `approval.answer` envelope: `authoritative`, grant `session.approve`, target `{logical_session_id, execution_id}`, body `{interaction_id, native_request_digest, choice}`.
- The host checks it with CAS: the interaction is still pending, the digest matches, the execution is the same, not expired. **The first valid authorized answer wins**; later ones get `refused: already_answered`.
- A generic signed user turn never answers a dialog.
- Interactions are voided at every fence close; answers are never replayed after a restart or resume.
- Interactions are processed independently of the goal loop (`goals.md` §4).

## 3. Human terminal

- `terminal.attach` needs the grant `terminal.raw` (humans only) and takes the holder's **exclusive input lease** for that execution. While a human holds it, automated dispatch pauses; items stay `queued`.
- `detach` releases the lease; the adapter runs a readiness probe; `unknown` parks.
- The terminal provider in the bridge is watch-only (an output projection under the viewer's audience grant); raw input goes only through the holder lease.
