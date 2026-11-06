# Test hermeticity

Status: proposed convention for every Go module of the swarm platform and its swarma modules.

A test suite must give the same verdict on a developer Mac, in hosted CI and in a strict Linux sandbox, except for a declared platform skip. In the strict sandbox the source is read-only, `/tmp` is not writable, the umask is 0077 and HOME points to an empty directory. A failure that appears only there is filed against the module as a hermeticity bug; it may be in the test or in the product.

A declared platform skip is a test that calls `t.Skip` with a reason when its platform facility is absent, for example macOS Keychain or Secure Enclave tests on Linux, or Linux-only tests on macOS. A declared skip is not a violation.

## Rules

1. **Write only to temporary directories.** Tests create files and directories only under `t.TempDir()` or under a directory created with `os.MkdirTemp("", …)`, which follows `TMPDIR`, except as rule 2 allows. They never write into the source tree, the package directory, `.` or a checkout-local `.temp`.
2. **No hardcoded `/tmp`.** A Unix socket path must fit `sun_path`: 104 bytes including the terminating NUL on macOS (so at most 103 bytes of path), 108 on Linux. A test that needs a short path, for a socket of its own or of a fixture agent, tmux (`TMUX_TMPDIR`) or gpg-agent (`GNUPGHOME`), uses a helper with these properties:
   - it uses `TMPDIR` when `TMPDIR` is set, absolute, and leaves room for the longest path the callers append;
   - otherwise, including when `TMPDIR` is empty or relative, it falls back to `/tmp`;
   - it creates a private 0700 directory per call and removes it on cleanup.

   Each module may keep its own copy, because Go `internal` packages cannot be imported across modules. The reference implementation is `internal/sockettest` in swarma-keyvault. It reserves 48 bytes for the appended part, so it keeps `TMPDIR` up to 55 bytes.
3. **Never rely on the umask.** A fixture that needs a specific mode sets it explicitly with `chmod` after creating the file or directory. Before calling the code under test it checks the actual mode and fails the test if the mode is wrong. Negative fixtures (unsafe permissions) must still be unsafe under umask 0077.
4. **Destructive host operations are opt-in, and bounded.** Tests that create or remove users or groups, change services, call `sudo` or change any host state outside their own temporary directories skip by default, and a test proves the default skips. Reading platform facilities such as the Keychain is not destructive; tests that write to them are, unless they use a test-only store. To run, all of these must hold:
   - an environment variable is set to an exact value that the module documents next to the test (for example in its test README). Being set or non-empty is not enough, because environment variables are inherited and can be left set in a shared shell;
   - a positive check confirms that the host is declared disposable for such tests, by a marker the module documents with the same test;
   - the test creates and changes only accounts, groups or services whose names carry a test-owned prefix, and it refuses to remove any name it did not create in the same run.
5. **Isolate HOME, runtime and live-session state.** Any test that can reach a user's home, a runtime's configuration or session store, or a live session sets these to temporary directories or removes them from the child environment:
   - `HOME`, `XDG_CONFIG_HOME` and runtime configuration directories such as `CLAUDE_CONFIG_DIR` and `CODEX_HOME`;
   - `SSH_AUTH_SOCK`, `GIT_SSH_COMMAND` and `GNUPGHOME`;
   - `TMUX` and `TMUX_TMPDIR`, because a test that drives tmux could otherwise reach a live pane;
   - `A2A_*`, Curator or runtime session variables, and model-provider credential variables. This list is open: a variable that points at a live session or credential belongs here even when it is not named.

   Tests never contact a real homeserver, a real model provider or a live agent socket. The hygiene lane does not yet enforce this with a network control, so reviewers check it in the code. Git fixtures set `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` to `/dev/null` (Git 2.32 or later), use a synthetic identity and never push. A test whose subject is signing may sign only with a key it generated inside the fixture, used directly as a key file (with `SSH_AUTH_SOCK` unset) or through an agent the fixture started itself; never with a real key or a real agent. Unsetting a variable does not prove that a key or socket is unreachable. Where real keys exist on the host, the lane's mask is the proof.

## Verification

- **Qualification lane.** Measures the product: private writable `/tmp`, a writable scratch copy of the checkout with the original hash-checked unchanged, umask 022, the toolchain from `go.mod`.
- **Hygiene lane.** Enforces these rules: read-only source, read-only `/tmp`, umask 0077, temporary HOME, masked key and agent paths. It supplies a `TMPDIR` short enough for the module's socket helper (55 bytes or less for the reference helper), so that the `/tmp` fallback is never needed. A fallback failure in this lane is a lane defect, not a test defect. It runs on the landed main of every module.

A fix for a hygiene failure includes a control that reproduces the old failure under the strict conditions and passes after the fix.
