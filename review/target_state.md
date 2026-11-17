# Target state of `uv-install-package-action`

Review date: 2026-11-17. Baseline: `main` at `ce6722d` (v0.2.0 + 82 commits). Breaking changes are
accepted. The future state matters more than backward compatibility.

## 1. Properties of the action

These are the properties the action must have. Every proposal below is judged against them.

| #   | Property                 | Meaning                                                                                                                                                           |
| --- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1  | **Single purpose**       | Install exactly `package-name==package-version` with uv, but only if that version is installable for the target Python version. Never substitute another version. |
| P2  | **Safe skip**            | An invalid version is not an error by default. The action skips the install, warns, and reports `is-valid-version=false`. Callers can opt in to failing.          |
| P3  | **Loud on real errors**  | Bad inputs, no uv, an unreachable index, or a failed install fail the job with a clear `::error::`. A real error is never reported as "invalid version".          |
| P4  | **Non-intrusive**        | The action installs only what the user asked for. It must not add helper packages (such as `feu`) to the user's environment.                                      |
| P5  | **Fast**                 | Few steps (one process start each), no redundant work, no sleeps, no post-install checks that cannot fail the job.                                                |
| P6  | **Simple**               | Small, single-purpose bash scripts that run on GNU/Linux and BSD/macOS (bash 3.2), each with a bats file. No logic in `action.yaml` beyond wiring.                |
| P7  | **Safe by construction** | Inputs reach scripts only through `env:`. Nothing is `eval`ed. `uv-args` is split into words, never interpreted by a shell.                                       |
| P8  | **Predictable contract** | Inputs, outputs and behaviour are small, documented in `README.md`, and identical to `action.yaml`.                                                               |
| P9  | **Minimal export**       | Only `action.yaml`, `LICENSE` and the scripts the action calls ship in the release archive. Everything else is `export-ignore`.                                   |
| P10 | **Pinned and immutable** | Third-party actions are pinned to SHAs. Releases are exact version tags (`vX.Y.Z`). No floating tags.                                                             |

## 2. Review of the current state

### 2.1 What is good (keep)

- The skip-instead-of-substitute behaviour (P1, P2) is clear and well documented.
- Inputs go through `env:`, every `run:` step has `set -euo pipefail` (P7).
- Logic is extracted into scripts with bats tests, including a bash 3.2 CI job (P6).
- `.gitattributes` exports only what the action needs (P9). Actions are SHA-pinned (P10).

### 2.2 Problems found

Ordered by impact.

| #   | Problem                                                                                                                                                                                                                                                                                                                                                                                     | Property broken |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| A1  | **Step 4 installs `feu[cli]` into the user's environment** with `uv pip install`. This pollutes the environment (feu and its dependencies can conflict with the package being tested), costs an install per run, and needs a hand-written retry loop with `sleep 2`. `feu install` then wraps `uv pip install` for no benefit.                                                              | P4, P5, P6      |
| A2  | **Step 7 "Verify installation" can never fail.** It guesses the import name (`name.replace("-", "_")`), which is wrong for `scikit-learn`, `pyyaml`, `pillow` and others. The docs claim it handles `scikit-learn -> sklearn`, but the script does not. On a miss it only warns, so it produces noise and no signal. It also adds two Python starts.                                        | P5, P8          |
| A3  | **Seven steps for what is three jobs**: validate, check, install. Steps 1 to 3 are three separate bash start-ups for input validation. The wildcard and import-name scripts are one-liners with their own test files and process spawns.                                                                                                                                                    | P5, P6          |
| A4  | **Auto-detected Python version is wrong for free-threaded builds.** `python --version` prints `3.13.0`, so a `3.13t` interpreter is checked as `3.13`. It also uses `python` (whatever is on `PATH`) while uv may target another interpreter.                                                                                                                                               | P3, P8          |
| A5  | **`uv-args` handling is inconsistent.** The shell-metacharacter warning is meaningless because the value is never shell-evaluated. In step 6 it is passed as one string to `feu install --installer-args`, so quoting depends on feu internals. The validity check (step 5) ignores `uv-args`, so a custom or private index is never consulted and the check can disagree with the install. | P3, P7, P8      |
| A6  | **`is-valid-version` is `true` for wildcards without a check.** The output then means "not checked" and the README documents a surprising failure mode (a wildcard that matches nothing fails the job).                                                                                                                                                                                     | P8              |
| A7  | **Failing on an invalid version needs a hand-written follow-up step** (shown in the README). This is a very common need.                                                                                                                                                                                                                                                                    | P2, P8          |
| A8  | **`installed-successfully` is derived from `steps.install-package.outcome`.** Because a failed install fails the job, the output can only be `true` or `false` because of a skip. It adds nothing over `is-valid-version`.                                                                                                                                                                  | P8              |
| A9  | **Prerequisites are under-documented.** `uv pip install` needs an active venv (`setup-uv` with `activate-environment: true`) or `UV_SYSTEM_PYTHON=1`. The README example shows `setup-uv` without it.                                                                                                                                                                                       | P8              |
| A10 | **Input validation is thin.** It checks emptiness and whitespace only. Names such as `-e`, `--pre`, `git+https://...` or `numpy==1` are accepted and become options or specifiers.                                                                                                                                                                                                          | P3, P7          |
| A11 | **Repository hygiene.** `.gitattributes` lists a missing `environment.yaml`. `tests/unit/` is empty. `invoke.yaml`/`tasks.py` duplicate the Makefile. `ci-action-edge-cases.yaml` is 232 lines of repeated steps. `README.md` has a long troubleshooting section that restates the steps.                                                                                                   | P6, P9          |

## 3. Target design

### 3.1 Contract

#### Inputs

| Name              | Required | Default       | Description                                                                                                                                                        |
| ----------------- | -------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `package-name`    | yes      | -             | Distribution name. Must match PEP 508 name syntax.                                                                                                                 |
| `package-version` | yes      | -             | Exact PEP 440 version (`2.0.2`) or a wildcard (`2.12.*`).                                                                                                          |
| `python-version`  | no       | auto-detected | Target Python: `X.Y` or free-threaded `X.Yt`. Patch versions are **rejected**, not silently normalized. Auto-detection uses the same interpreter uv installs into. |
| `uv-args`         | no       | `""`          | Extra arguments for `uv pip install`, split on whitespace (no shell quoting). Applied to **both** the check and the install.                                       |
| `fail-on-invalid` | no       | `"false"`     | New. If `"true"`, an invalid version fails the job instead of being skipped (P2, A7).                                                                              |

#### Outputs

| Name               | Description                                                                                          |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| `is-valid-version` | `true` or `false`. For wildcards it is the result of a real check (see 3.3), never "assumed true".   |
| `installed`        | `true` if the package was installed, `false` if skipped. Renamed from `installed-successfully` (A8). |

If you want to remove an output to stay minimal, `installed` is the one to drop: it equals
`is-valid-version` in every non-failing run. It is kept only because it reads better in `if:`
expressions.

#### Behaviour matrix

| Situation                                | Result                                                     |
| ---------------------------------------- | ---------------------------------------------------------- |
| Valid version                            | Install, `is-valid-version=true`, `installed=true`         |
| Invalid version, `fail-on-invalid=false` | Warning, no install, `false` / `false`, job succeeds       |
| Invalid version, `fail-on-invalid=true`  | `::error::`, job fails                                     |
| Bad input, uv missing, index unreachable | `::error::`, job fails (never reported as invalid version) |
| Install fails                            | Job fails, uv output visible                               |

### 3.2 Step layout (7 steps to 3)

```text
Step 1  Validate     scripts/validate_inputs.sh   uv present, inputs, python-version -> $GITHUB_OUTPUT
Step 2  Check        scripts/check_version.sh     is-valid-version -> $GITHUB_OUTPUT
Step 3  Install      scripts/install_package.sh   only if is-valid-version == true
```

- **Step 1** merges the old steps 1 to 3 into one script. It checks `command -v uv`, validates
  `package-name` (PEP 508 name regex, no leading `-`), `package-version` (non-empty, no whitespace,
  no leading `-`), and `python-version`. When `python-version` is empty it asks the interpreter uv
  will use:
  A short `python -c` call run through `uv run --no-project` prints `X.Y`, plus `t` when
  `sysconfig.get_config_var("Py_GIL_DISABLED")` is set.
  It writes `python-version` to `$GITHUB_OUTPUT`. A wrong format is one `::error::` with the
  expected format.
- **Step 2** runs feu in an **ephemeral** environment, so nothing is added to the user's environment
  (A1, P4):
  `uvx --from 'feu[cli]>=0.8,<1' feu check-valid-version` with `--pkg-name`, `--pkg-version` and
  `--python-version`.
  uv has its own download retries (`UV_HTTP_RETRIES`), so the retry loop and `sleep` go away. Stdout
  is compared to `True`/`False`; any other result or a non-zero exit is a real error (P3). Stderr is
  passed through unchanged, with no temp file.
- **Step 3** is
  `uv pip install "${PACKAGE_NAME}==${PACKAGE_VERSION}" ${UV_ARGS_ARRAY[@]+"${UV_ARGS_ARRAY[@]}"}`
  with `uv-args` split into an array by `read -r -a` (bash 3.2 safe, no `eval`). It replaces
  `feu install` and the import check. A non-zero uv exit fails the job, which is the verification
  (A2).

`action.yaml` keeps the numbered `Step N` comments, with `env:` wiring and one script call per step,
so it shrinks by roughly two thirds.

### 3.3 Decisions

| Topic                   | Decision                                                                                                                                                                                                                                                                                           | Why                                                                                                             |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Keep feu?               | **Yes, but only through `uvx`.** feu is the same author's tool and already implements the PyPI `requires_python` and yanked checks, so there is no new code to maintain.                                                                                                                           | Smallest change that fixes A1. Rewriting the check in bash or Python would add code to test and own.            |
| Remove `feu install`    | **Yes.** Call `uv pip install` directly.                                                                                                                                                                                                                                                           | Same result, one fewer layer, `uv-args` handled in one place (A5).                                              |
| Remove import check     | **Yes.** Delete `get_import_name.sh`, its bats file and step 7.                                                                                                                                                                                                                                    | It cannot fail the job and guesses wrongly (A2). Users who want a smoke test can add their own `python -c`.     |
| Remove wildcard script  | **Yes.** Replace with a `case "$v" in *'*'*)` inside `check_version.sh`.                                                                                                                                                                                                                           | A one-line test does not need its own script, bats file and process (A3).                                       |
| Wildcards               | For `X.Y.*`, `check_version.sh` runs `uv pip install --dry-run --python-version "$PY" "pkg==X.Y.*" $UV_ARGS`. Exit 0 gives `true`. A non-zero exit gives `false` and the uv message is printed in the warning. This is the one place a resolver error counts as "invalid", and the output says so. | Gives wildcards a real answer (A6) without feu support. If that proves too ambiguous, reject wildcards (see 5). |
| Python version input    | Accept only `X.Y` and `X.Yt`. Reject `3.10.1`.                                                                                                                                                                                                                                                     | Silent normalization and its warning code hide a user mistake. Removes the normalize branch (P6).               |
| `uv-args` and the check | Pass `uv-args` to the check as `UV_*`-style options only where supported. Document that feu queries the default PyPI index, and that for private indexes users should set `fail-on-invalid: "false"` and rely on install errors, or skip the check (see 5).                                        | A5 cannot be fully fixed with feu. Be explicit rather than pretend.                                             |
| Metacharacter warning   | Remove.                                                                                                                                                                                                                                                                                            | Nothing is shell-evaluated, so it is misleading noise (A5).                                                     |
| Emoji in logs           | Keep a short prefix per step (`Step 2/3`), drop the multi-line banners.                                                                                                                                                                                                                            | Logs stay readable and the action stays small.                                                                  |

### 3.4 Scripts and tests

| Script                       | Responsibility                                                      | Replaces                                                             |
| ---------------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `scripts/validate_inputs.sh` | uv present, validate all inputs, resolve and print `python-version` | steps 1 to 3, `validate_python_version.sh`, old `validate_inputs.sh` |
| `scripts/check_version.sh`   | exact check with feu, wildcard check with uv dry-run                | step 5, `is_wildcard_version.sh`                                     |
| `scripts/install_package.sh` | split `uv-args`, run `uv pip install`                               | steps 4, 6, 7, `get_import_name.sh`                                  |

Rules for the tests, per `CLAUDE.md`: one `tests/bats/test_<script>.bats` per script, `uv`/`uvx`
mocked on `PATH` by a function or a stub directory, one behaviour per test. Cases to cover:

- `validate_inputs.sh`: empty or invalid name, name starting with `-`, whitespace in version, `3`,
  `3.10.1`, `python3.10`, `3.13t`, empty `python-version` (stub `uv run`), uv missing.
- `check_version.sh`: feu prints `True`, `False`, garbage, exits non-zero; wildcard accepted and
  rejected by the stub; free-threaded `3.13t`; `fail-on-invalid` true and false.
- `install_package.sh`: no args, several args, an arg with `=`, empty `uv-args`, uv failure
  propagates, bash 3.2 empty-array expansion.

Every bug fix keeps a regression test. A new regression test is needed for A4 (free-threaded
auto-detection).

### 3.5 Workflows (target)

Keep the role-based layout and conventions from `CLAUDE.md`. Changes:

1. **Shrink `ci-action-edge-cases.yaml`** (232 lines). Drive it from a matrix of cases (`name`,
   inputs, `expect: success|failure`) and use one step plus one assertion, instead of one copy of
   the steps per case. Add cases for `fail-on-invalid`, wildcards, and a free-threaded auto-detect.
2. **Add an assertion step on outputs** in `ci-action-deps.yaml` for `is-valid-version` and
   `installed`, so a regression in outputs fails CI rather than only skipping the pytest step.
3. **Assert the export set** in `ci-shell.yaml` or a small `ci-export.yaml`:
   `git archive --worktree-attributes HEAD | tar t` must equal `action.yaml`, `LICENSE`, and
   `scripts/*.sh` (P9).
4. **Keep** `nightly*.yaml`, `lib-*.yaml`, `bot-*.yaml` and `security-*.yaml` as they are. They are
   conventional and cheap, and not part of the shipped action.
5. Use `setup-uv` with `activate-environment: true` in every job that calls the action (already the
   case in `ci-action-deps.yaml`) and document it (A9).

### 3.6 Repository hygiene

- `.gitattributes`: remove the `environment.yaml` line (file does not exist). Add
  `/review/ export-ignore` for this directory (P9).
- `tests/unit/` is empty. Delete it and the matching lines in `tests/TESTING.md` until there is
  Python code to test.
- Decide between `invoke` (`tasks.py`, `invoke.yaml`) and `make`. `CLAUDE.md` says to use the
  Makefile, so remove `tasks.py`, `invoke.yaml` and the `inv ...` references in `tests/TESTING.md`
  unless something still needs them.
- `README.md`: cut it to what a user needs. Keep overview, prerequisites (with the venv note),
  usage, inputs, outputs, behaviour matrix, limitations. Drop the "How it works" step list and the
  troubleshooting sections that restate error messages. Keep the "What's new" pointer to releases.
- Bump to a new **minor** release `v0.3.0` (pre-1.0 breaking changes). Release notes list the
  breaking changes in section 4. No floating tags.

## 4. Breaking changes (to flag in the PR and release notes)

| Change                                                   | Migration                                                      |
| -------------------------------------------------------- | -------------------------------------------------------------- |
| Output `installed-successfully` renamed `installed`      | Update `steps.<id>.outputs.*` references.                      |
| `python-version` `X.Y.Z` is now an error                 | Pass `X.Y`.                                                    |
| `is-valid-version` for wildcards comes from a real check | A wildcard matching nothing is now `false`, not a job failure. |
| No more import verification step and its warnings        | Add `python -c "import ..."` if wanted.                        |
| `feu` is no longer installed in the user's environment   | Install feu yourself if you used it afterwards.                |
| `uv-args` is whitespace-split with no shell quoting      | Avoid quoted arguments containing spaces.                      |
| New input `fail-on-invalid` (additive)                   | None.                                                          |

## 5. Open questions (need an owner decision)

1. **Wildcards**: keep them with the uv dry-run check (proposed), or drop them for a simpler
   contract ("exact versions only")? Dropping removes the dry-run path and its tests, but the README
   and CI already use wildcards, so this is a product call.
2. **Private indexes**: feu always queries default PyPI. Options: (a) document the limit, as
   proposed; (b) add `check-version: "false"` to skip step 2 and install directly; (c) use
   `uv pip install --dry-run` for every check and treat any resolver failure as "invalid", which
   honours `uv-args` but blurs P3. Recommendation: (a) now, (b) only if users ask.
3. **Keep the `installed` output** or drop it (see 3.1)?
4. **Invoke vs make**: confirm nothing outside this repo depends on `tasks.py`.

## 6. Migration plan (one PR per item, each branched from `main`)

1. `refactor/merge-validation-scripts`: new `validate_inputs.sh` (uv, inputs, python-version incl.
   free-threaded auto-detect), delete the old scripts and tests, add tests. Fixes A4, A10.
2. `refactor/check-version-with-uvx`: new `check_version.sh`, `uvx` instead of installing feu, drop
   retry loop and temp file. Fixes A1, A6.
3. `refactor/install-with-uv-directly`: `install_package.sh`, remove step 7 and
   `get_import_name.sh`, rename the output, add `fail-on-invalid`. Fixes A2, A5, A7, A8.
4. `refactor/slim-action-yaml`: collapse to three steps, update the `Step N` comments, update
   `README.md` and `tests/TESTING.md`. Fixes A3, A9.
5. `ci/table-driven-edge-cases`: matrix-driven edge cases, output assertions, export-set check.
6. `chore/repo-hygiene`: `.gitattributes`, empty `tests/unit`, invoke removal.
7. Release `v0.3.0`.

Expected size change: `action.yaml` about 290 lines to about 90, scripts 4 to 3, steps 7 to 3,
process starts per run roughly halved, and no packages installed beyond the requested one.

## 7. Checks for each PR

Per `CLAUDE.md`: `make format`, `make lint`, `bats tests/bats/` (also with bash 3.2 on macOS),
`pytest`, and `git archive --worktree-attributes HEAD | tar t`. The `ci-action*` and nightly
workflows run only on GitHub, so each PR must say they were not run locally and that CI was not
awaited.
