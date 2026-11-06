# Test hermeticity

Status: proposed convention for every Go module of the swarm platform and its swarma modules.

A test suite must give the same verdict on a developer Mac, in hosted CI and in a strict Linux sandbox. In the strict sandbox the source is read-only, `/tmp` is not writable, the umask is 0077 and HOME points to an empty directory. A test that fails only there is a test defect, not a product defect.

## Rules

1. **Write only to temporary directories.** Tests create files and directories only under `t.TempDir()` or under a directory created with `os.MkdirTemp("", …)`, which follows `TMPDIR`. They never write into the source tree, the package directory, `.` or a checkout-local `.temp`.
2. **No hardcoded `/tmp`.** A test that needs a short path, for example for a Unix socket within the platform's 104-byte `sun_path` limit, uses a shared helper. The helper uses `TMPDIR` when the full path fits, falls back to `/tmp` only when it does not, creates a private 0700 directory and removes it on cleanup. The reference implementation is `internal/sockettest` in swarma-keyvault.
3. **Never rely on the umask.** A fixture that needs a specific mode sets it explicitly with `chmod` after creating the file or directory. Before calling the code under test it checks the actual mode and fails the test if the mode is wrong. Negative fixtures (unsafe permissions) must still be unsafe under umask 0077.
4. **Destructive host operations are opt-in.** Tests that create or remove users or groups, change services, call `sudo` or modify anything outside their own temporary directories run only when an explicit environment variable enables them. By default they skip, and a test proves the default skips.
5. **Isolate HOME and runtime configuration.** Any test that can reach a user's home or a runtime's configuration or session store sets `HOME` and the relevant configuration directories (for example `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `XDG_CONFIG_HOME`) to temporary directories. Git fixtures set `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` to `/dev/null`, use a synthetic identity, and never sign or push.

## Verification

- **Qualification lane.** Measures the product: private writable `/tmp`, a writable scratch copy of the checkout with the original hash-checked unchanged, umask 022, the toolchain from `go.mod`.
- **Hygiene lane.** Enforces these rules: read-only source, read-only `/tmp`, umask 0077, temporary HOME. It runs on the landed main of every module. A red result here is filed against the module as a test-hermeticity bug, not as a qualification failure.

A fix for a hygiene failure includes a control that reproduces the old failure under the strict conditions and passes after the fix.
