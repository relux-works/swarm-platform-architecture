# Test hermeticity

Status: proposed convention for every Go module of the swarm platform and its swarma modules.

A test suite must give the same verdict on a developer Mac, in hosted CI and in a strict Linux sandbox, except for a declared platform skip. In the strict sandbox the source is read-only, `/tmp` is not writable, the umask is 0077 and HOME points to an empty directory. A test that fails only there is a test defect, not a product defect.

A declared platform skip is a test that calls `t.Skip` with a reason when its platform facility is absent, for example macOS Keychain or Secure Enclave tests on Linux, or Linux-only tests on macOS. A declared skip is not a violation.

## Rules

1. **Write only to temporary directories.** Tests create files and directories only under `t.TempDir()` or under a directory created with `os.MkdirTemp("", …)`, which follows `TMPDIR`. They never write into the source tree, the package directory, `.` or a checkout-local `.temp`.
2. **No hardcoded `/tmp`.** A test that needs a short path, for example for a Unix socket within the platform's 104-byte `sun_path` limit, uses a shared helper. The helper uses `TMPDIR` when the full path fits, falls back to `/tmp` only when it does not, creates a private 0700 directory and removes it on cleanup. The reference implementation is `internal/sockettest` in swarma-keyvault.
3. **Never rely on the umask.** A fixture that needs a specific mode sets it explicitly with `chmod` after creating the file or directory. Before calling the code under test it checks the actual mode and fails the test if the mode is wrong. Negative fixtures (unsafe permissions) must still be unsafe under umask 0077.
4. **Destructive host operations are opt-in, and bounded.** Tests that create or remove users or groups, change services, call `sudo` or modify anything outside their own temporary directories skip by default, and a test proves the default skips. To run, all of these must hold:
   - an environment variable is set to an exact, documented value. Being set or non-empty is not enough, because environment variables are inherited and can be left set in a shared shell;
   - a positive check confirms that the host is declared disposable for such tests;
   - the test creates and changes only accounts, groups or services whose names carry a test-owned prefix, and it refuses to remove any name it did not create in the same run.
5. **Isolate HOME, runtime and live-session state.** Any test that can reach a user's home, a runtime's configuration or session store, or a live session sets these to temporary directories or removes them from the child environment:
   - `HOME`, `XDG_CONFIG_HOME` and runtime configuration directories such as `CLAUDE_CONFIG_DIR` and `CODEX_HOME`;
   - `SSH_AUTH_SOCK`, `GIT_SSH_COMMAND` and `GNUPGHOME`;
   - `TMUX` and `TMUX_TMPDIR`, because a test that drives tmux could otherwise reach a live pane;
   - `A2A_*` and any Curator or runtime session variables.

   Tests never contact a real homeserver, a real model provider or a live agent socket. Git fixtures set `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` to `/dev/null`, use a synthetic identity and never push. A test whose subject is signing may sign only with a key it generated inside the fixture, through an agent the fixture started itself; never with a real key or a real agent. Unsetting a variable does not prove that a key or socket is unreachable. Where real keys exist on the host, the lane's mask is the proof.

## Verification

- **Qualification lane.** Measures the product: private writable `/tmp`, a writable scratch copy of the checkout with the original hash-checked unchanged, umask 022, the toolchain from `go.mod`.
- **Hygiene lane.** Enforces these rules: read-only source, read-only `/tmp`, umask 0077, temporary HOME, masked key and agent paths. It supplies a short `TMPDIR` (55 bytes or less) so that socket helpers never need their `/tmp` fallback; a fallback failure in this lane is a lane defect, not a test defect. It runs on the landed main of every module. A red result here is filed against the module as a test-hermeticity bug, not as a qualification failure.

A fix for a hygiene failure includes a control that reproduces the old failure under the strict conditions and passes after the fix.
