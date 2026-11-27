# Target state of `uv-install-package-action`

Review date: 2026-11-17. Baseline: `main` at `ce6722d` (v0.2.0 + 82 commits). Breaking changes are
accepted. The future state matters more than backward compatibility.

## 0. Context and scope

- The action is designed to run in a **matrix of jobs** (Python version × OS × package version). In
  such a matrix it is hard to list by hand which package versions work with which Python version
  (e.g. 3.13 vs 3.14 vs 3.15). The action answers "is this version usable here?" so the workflow can
  stay a plain cross product, and the invalid cells skip cleanly (or fail, on request).
- **In scope**: GitHub-hosted and self-hosted Linux and macOS runners (GNU and BSD tools, bash 3.2).
- **Out of scope**: Windows.
- **Dependencies the action may install**: `feu`, because it holds the compatibility knowledge
  (curated version ranges per package and target, plus companion pins such as `numpy<2` for old
  `jax`). It cannot be replaced by a bare `uv pip install` without losing that knowledge.
- **Assumed `feu` version**: `feu>=0.9.0,<1` (verified with the pre-release, section 2.3). It adds
  wildcard support, automatic detection of the target Python, and `shlex` handling of installer
  arguments.

## 1. Properties of the action

Every proposal below is judged against these properties.

| #   | Property                 | Meaning                                                                                                                                                                                                                             |
| --- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P1  | **Single purpose**       | Install `package-name` at the requested `package-version`, but only if that version is valid for the target Python. An exact version is never substituted by another one. A wildcard installs the newest valid release matching it. |
| P2  | **Two modes**            | `skip` (default): an invalid version is not an error. The action warns, installs nothing and reports `is-valid-version=false`. `fail`: an invalid version fails the job with an `::error::`.                                        |
| P3  | **Loud on real errors**  | Bad inputs, no uv, a network failure, or a failed install fail the job with a clear `::error::` in both modes. A real error is never reported as "invalid version".                                                                 |
| P4  | **Self-sufficient**      | The action installs every dependency it needs to do its job (today `feu`). It adds nothing else to the environment.                                                                                                                 |
| P5  | **Fast**                 | No redundant work, no sleeps, no post-install check that cannot fail the job.                                                                                                                                                       |
| P6  | **Simple**               | Small bash scripts that work on GNU/Linux and BSD/macOS (bash 3.2), each with a bats file. No logic in `action.yaml` beyond wiring.                                                                                                 |
| P7  | **Small steps**          | Each step does one thing and has one reason to fail. Steps are grouped as `1.x`, `2.x`, `3.x`. A failure message points at one step.                                                                                                |
| P8  | **Safe by construction** | Inputs reach scripts only through `env:`. Nothing is `eval`ed.                                                                                                                                                                      |
| P9  | **Predictable contract** | Inputs, outputs and behaviour are small, documented in `README.md`, and identical to `action.yaml`.                                                                                                                                 |
| P10 | **Minimal export**       | Only `action.yaml`, `LICENSE` and the scripts the action calls ship in the release archive. Everything else is `export-ignore`.                                                                                                     |
| P11 | **Pinned and immutable** | Third-party actions are pinned to SHAs. Releases are exact version tags (`vX.Y.Z`). No floating tags.                                                                                                                               |

## 2. Review of the current state

### 2.1 What is good (keep)

- The skip-instead-of-substitute behaviour (P1, P2) is clear and well documented, and fits matrices.
- Inputs go through `env:`, every `run:` step has `set -euo pipefail` (P8).
- Logic is extracted into scripts with bats tests, including a bash 3.2 CI job (P6).
- `.gitattributes` exports only what the action needs (P10). Actions are SHA-pinned (P11).
- Using `feu` for both the check and the install (compat table plus companion pins).

### 2.2 Problems found

Ordered by impact.

| #   | Problem                                                                                                                                                                                                                                                                                          | Property broken |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------- |
| A1  | **Wrong description of the check.** The README and the error message say the check queries PyPI. With `feu 0.8.x` it does not: it reads a curated table of version ranges per package and target (an unknown package is always "valid"). "Failed to query PyPI" is therefore a misleading error. | P3, P9          |
| A2  | **Step 5 is a big step.** One step does wildcard detection, runs feu, captures stderr in a temp file, builds the error text and parses `True`/`False`. Step 4 is a hand-written retry loop with `sleep 2`.                                                                                       | P5, P6, P7      |
| A3  | **Step 7 "Verify installation" can never fail.** It guesses the import name (`name.replace("-", "_")`), which is wrong for `scikit-learn`, `pyyaml`, `pillow`. The docs claim it handles `scikit-learn -> sklearn`, but the script does not. It only warns, and costs two Python starts.         | P5, P9          |
| A4  | **Auto-detected Python version is wrong for free-threaded builds.** `python --version` prints `3.13.0`, so a `3.13t` interpreter is checked as `3.13`.                                                                                                                                           | P3, P9          |
| A5  | **Wildcards are not checked.** `is-valid-version` is `true` for `2.12.*` without any check. In a matrix this is the worst case: the invalid cells fail the job instead of skipping (`feu 0.8.x` cannot parse a wildcard).                                                                        | P2, P9          |
| A6  | **Only one mode on invalid versions.** Failing needs a hand-written follow-up step in the workflow (shown in the README).                                                                                                                                                                        | P2, P9          |
| A7  | **`uv-args` handling is inconsistent.** The shell-metacharacter warning is meaningless because the value is never shell-evaluated. The validity check ignores `uv-args`.                                                                                                                         | P3, P8, P9      |
| A8  | **Prerequisites are under-documented.** `uv pip install` needs an active venv (`setup-uv` with `activate-environment: true`) or `UV_SYSTEM_PYTHON=1`. The README example omits it.                                                                                                               | P9              |
| A9  | **Input validation is thin.** Only emptiness and whitespace are checked. Names such as `-e`, `--pre`, `git+https://...` are accepted and become options.                                                                                                                                         | P3, P8          |
| A10 | **`feu` is installed with the wrong extras for `0.9`.** `feu[cli]` is not enough for wildcard checks, which also need `requests` (`feu[cli,requests]`).                                                                                                                                          | P3              |
| A11 | **Repository hygiene.** `.gitattributes` lists a missing `environment.yaml`. `tests/unit/` is empty. `invoke.yaml`/`tasks.py` duplicate the Makefile. `ci-action-edge-cases.yaml` is 232 lines of repeated steps. `README.md` has a long troubleshooting section that restates the steps.        | P6, P10         |

### 2.3 What was verified for `feu 0.9.0a0`

Tested in an isolated venv with `feu[cli]==0.9.0a0` plus `requests` (on PyPI as `0.9.0a0`):

| Command (`check-valid-version`)  | `0.8.4`                  | `0.9.0a0`                               |
| -------------------------------- | ------------------------ | --------------------------------------- |
| `numpy 2.3.0`, Python 3.9 / 3.11 | `False` / `True`         | `False` / `True`                        |
| `numpy 2.3.*`, Python 3.9 / 3.11 | crash (`InvalidVersion`) | `False` / `True`                        |
| `numpy 2.*`, Python 3.11         | crash                    | `True`                                  |
| `numpy 9.9.*`, Python 3.11       | crash                    | `False`                                 |
| `torch 2.0.*`, Python 3.13       | crash                    | `False`                                 |
| `--python-version` omitted       | not supported            | uses the current interpreter, incl. `t` |

`feu install` in `0.9.0a0`:

- `--pkg-version='2.3.*'` installs the newest valid match (`numpy==2.3.5` in the test).
- No valid match prints `No version of package torch matches '9.*' for target ...`.
- `--installer-args` is split once with `shlex.split`, so quoted arguments work.
- It installs into the interpreter that runs `feu`, and **a non-valid exact version is replaced by
  the closest compatible one** (documented in `--help`). The action must therefore always check
  first, so that P1 (never substitute) holds.
- Wildcard checks fetch the release list from PyPI (default index), so they need network access and
  `requests`.

New behaviours the action must handle:

- `check-valid-version` exits with status `1` when it prints `False`. A crash also exits with `1`.
  The script must therefore read stdout (`True`/`False`) and treat any other output as a real error.
- The unknown-package case stays "valid" (no table entry), so `fail` mode does not catch typos in
  `package-name`; the install step does, with uv's own error.

## 3. Target design

### 3.1 Contract

#### Inputs

| Name                   | Required | Default       | Description                                                                                                                                                               |
| ---------------------- | -------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `package-name`         | yes      | -             | Distribution name. Must match PEP 508 name syntax.                                                                                                                        |
| `package-version`      | yes      | -             | Exact PEP 440 version (`2.0.2`) or a wildcard (`2.12.*`).                                                                                                                 |
| `python-version`       | no       | auto-detected | Target Python: `X.Y` or free-threaded `X.Yt`. Patch versions are **rejected**. When empty, `feu` uses the interpreter it runs in (the one the package is installed into). |
| `uv-args`              | no       | `""`          | Extra arguments for `uv pip install`, parsed with `shlex` by `feu`, so quotes work.                                                                                       |
| `invalid-version-mode` | no       | `skip`        | `skip`: warn and install nothing. `fail`: fail the job. Any other value is an input error. (P2, A6)                                                                       |

#### Outputs

| Name                | Description                                                                                     |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| `is-valid-version`  | `true` or `false`. Result of the `feu` check, for exact versions and wildcards.                 |
| `installed`         | `true` if the package was installed, `false` if skipped. Renamed from `installed-successfully`. |
| `installed-version` | Version actually installed (e.g. `2.3.5` for `2.3.*`), empty string if skipped. New.            |

#### Behaviour matrix

| Situation                             | Result                                                         |
| ------------------------------------- | -------------------------------------------------------------- |
| Valid version                         | Install, `is-valid-version=true`, `installed=true`             |
| Invalid version, mode `skip`          | Warning, no install, `false` / `false`, job succeeds           |
| Invalid version, mode `fail`          | `::error::`, job fails (`is-valid-version=false` is still set) |
| Bad input, uv missing, feu cannot run | `::error::`, job fails (never reported as invalid version)     |
| Install fails                         | Job fails, uv output visible                                   |

### 3.2 Step layout (many small steps, grouped)

```text
1.x  Prepare
  1.1  Verify uv is installed            scripts/check_uv.sh
  1.2  Validate package inputs and mode  scripts/validate_inputs.sh
  1.3  Validate the Python version       scripts/validate_python_version.sh

2.x  Check
  2.1  Install feu                       uv pip install "feu[cli,requests]>=0.9.0,<1"
  2.2  Check the version                 scripts/check_version.sh             -> is-valid-version
  2.3  Handle an invalid version         scripts/handle_invalid_version.sh

3.x  Install
  3.1  Install the package               python -m feu install ...
  3.2  Read the installed version       scripts/get_installed_version.sh
```

- **1.1** `command -v uv`, prints the path and version. Fails with an `::error::` if missing.
- **1.2** Validates `package-name` (PEP 508 name regex, no leading `-`), `package-version`
  (non-empty, no whitespace, no leading `-`) and `invalid-version-mode` (`skip` or `fail`).
- **1.3** Accepts empty, `X.Y` and `X.Yt`; rejects everything else (including `3.10.1`) with the
  expected format in the message. Empty is passed through: `feu` detects the target itself (A4).
- **2.1** One `uv pip install` of `feu[cli,requests]>=0.9.0,<1`. No retry loop and no sleep: uv
  has its own network retries (`UV_HTTP_RETRIES`). `feu` goes into the same environment the package
  is installed into, so `feu install` and the check agree on the interpreter (P4).
- **2.2** Runs `python -m feu check-valid-version`, passing `--python-version` only when it was
  given. It reads stdout, ignores the exit status (which is `1` for `False`), and writes
  `is-valid-version`. Anything other than `True`/`False` on stdout is a real error with the stderr
  text attached (P3, A1).
- **2.3** Runs only when the version is invalid. In `skip` mode it prints one `::warning::` and
  returns 0. In `fail` mode it prints one `::error::` and returns 1. The message names the package,
  the version and the Python version.
- **3.1** Runs `python -m feu install` with `--installer-name=uv`, `--installer-args`, `--pkg-name`
  and `--pkg-version` (and `--python-version` if given). It keeps feu's companion pins. The
  `installed` output is `steps.<id>.outcome == 'success'`.
- **3.2** Runs after a successful 3.1. `get_installed_version.sh` runs `uv pip show` for the package
  and prints the `Version:` field, written to the `installed-version` output. The output is an empty
  string when the install was skipped. A missing package after a successful install is a real error.

The old steps "Install dependencies", "Verify installation", the import-name script and the wildcard
script disappear. `action.yaml` keeps the numbered `Step N` comments and only wires `env:` to a
script call per step.

### 3.3 Decisions

| Topic                 | Decision                                                                                                                                | Why                                                                                                                               |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Keep feu              | **Yes**, for both the check and the install, installed into the environment.                                                            | It holds the compatibility table and companion pins. Dropping it needs a replacement source of truth that we do not have (see 5). |
| Drop `feu install`    | **No.** Call it for the install.                                                                                                        | It adds pins that a plain `uv pip install` would not (e.g. `numpy<2` for old `jax`). It also handles wildcards.                   |
| `feu` version         | `>=0.9.0a0,<1`.                                                                                                                         | Wildcards, auto-detected target, `shlex` arguments. The pin allows the pre-release because the specifier names one.               |
| Wildcards             | **Keep**, checked by `feu` (replaces the earlier "drop" decision, which was based on the lack of a sound check).                        | In a matrix, `2.12.*` avoids listing patch versions. `feu 0.9.0a0` makes the check real (A5).                                     |
| Python auto-detection | Delegate to `feu` (current interpreter, including `t`).                                                                                 | Removes our own detection code and fixes A4.                                                                                      |
| Remove import check   | **Yes.** Delete `get_import_name.sh`, its bats file and the step.                                                                       | It cannot fail the job and guesses wrongly (A3).                                                                                  |
| Python version input  | Accept only `X.Y` and `X.Yt`, plus empty.                                                                                               | Silent normalization hides a user mistake.                                                                                        |
| `uv-args` and check   | Document that the check does not use `uv-args` (exact check: curated table; wildcard check: default PyPI). Decision (a) from section 5. | Cannot be fixed on the action side. Be explicit.                                                                                  |
| Metacharacter warning | Remove.                                                                                                                                 | Nothing is shell-evaluated (A7).                                                                                                  |
| Log style             | One short line per step (`Step 2.2: ...`), no multi-line banners.                                                                       | Readable logs, small action.                                                                                                      |

### 3.4 Scripts and tests

| Script                               | Responsibility                                        | Replaces                                      |
| ------------------------------------ | ----------------------------------------------------- | --------------------------------------------- |
| `scripts/check_uv.sh`                | uv is available, print path and version               | old step 1                                    |
| `scripts/validate_inputs.sh`         | name, version, mode                                   | old step 2 and script                         |
| `scripts/validate_python_version.sh` | empty, `X.Y`, `X.Yt` only; print the value            | old step 3 and script (normalization removed) |
| `scripts/check_version.sh`           | run feu check, parse stdout, write `is-valid-version` | old step 5, `is_wildcard_version.sh`          |
| `scripts/handle_invalid_version.sh`  | `skip` warning or `fail` error                        | hand-written follow-up step in user workflows |
| `scripts/get_installed_version.sh`   | print the installed version of the package            | new (`installed-version` output)              |

Steps 2.1 and 3.1 are single commands and stay inline in `action.yaml`.

Rules for the tests, per `CLAUDE.md`: one `tests/bats/test_<script>.bats` per script, external
commands (`uv`, `python -m feu`) mocked on `PATH`, one behaviour per test. Cases to cover:

- `check_uv.sh`: uv present, uv missing.
- `validate_inputs.sh`: empty or invalid name, name starting with `-`, whitespace in version, a
  wildcard, bad mode, both valid modes.
- `validate_python_version.sh`: empty, `3.10`, `3.13t`, `3`, `3.10.1`, `python3.10`, `3.x`.
- `check_version.sh`: stdout `True`; `False` with exit 1; garbage stdout; crash with a stderr
  message; wildcard; `--python-version` passed only when set; `3.13t`.
- `handle_invalid_version.sh`: `skip` returns 0 with a warning, `fail` returns 1 with an error.
- `get_installed_version.sh`: version printed for an installed package, package not found, empty
  name, extra output lines ignored.

Every bug fix keeps a regression test, including one for A4 (free-threaded) in `check_version.sh`.

### 3.5 Workflows (target)

Keep the role-based layout and conventions from `CLAUDE.md`. Changes:

1. **Shrink `ci-action-edge-cases.yaml`** (232 lines). Drive it from a matrix of cases (`name`,
   inputs, `expect: success|failure`) with one step plus one assertion. Add cases for
   `invalid-version-mode: fail`, wildcards (valid and invalid for the Python version), and
   free-threaded auto-detection.
2. **Add an assertion step on outputs** in `ci-action-deps.yaml` for `is-valid-version` and
   `installed`, so an output regression fails CI instead of only skipping the pytest step.
3. **Assert the export set** (`git archive --worktree-attributes HEAD | tar t` equals `action.yaml`,
   `LICENSE` and `scripts/*.sh`) in a small `ci-export.yaml` called from `ci.yaml` (P10).
4. **Keep** `nightly*.yaml`, `lib-*.yaml`, `bot-*.yaml` and `security-*.yaml` as they are.
5. Use `setup-uv` with `activate-environment: true` in every job that calls the action (already the
   case in `ci-action-deps.yaml`) and document it (A8).

### 3.6 Repository hygiene

- `.gitattributes`: remove the `environment.yaml` line (file does not exist). `/review/` is already
  `export-ignore` (PR #338).
- `tests/unit/` is empty. Delete it and its lines in `tests/TESTING.md` until there is Python code
  to test.
- Remove `tasks.py`, `invoke.yaml` and the `inv ...` references in `tests/TESTING.md` (confirmed
  that nothing depends on them; `CLAUDE.md` says to use the Makefile).
- `README.md`: cut to what a user needs: overview and the matrix use case, prerequisites (with the
  venv note), usage, inputs, outputs, behaviour matrix, limitations. Drop the "How it works" list
  and the troubleshooting sections that restate error messages. Fix the "queries PyPI" wording (A1).
- Release `v0.3.0` (pre-1.0 breaking changes) only after `feu 0.9.0` is stable, with notes listing
  section 4. No floating tags.

## 4. Breaking changes (to flag in the PR and release notes)

| Change                                                            | Migration                                                               |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Output `installed-successfully` renamed `installed`               | Update `steps.<id>.outputs.*` references.                               |
| `python-version` `X.Y.Z` is now an error                          | Pass `X.Y`.                                                             |
| Wildcards get a real check                                        | A wildcard matching nothing is now skipped (`skip`), not a job failure. |
| No more import verification step and its warnings                 | Add `python -c "import ..."` if wanted.                                 |
| Auto-detected Python includes `t` for free-threaded builds        | None for most users; a `3.13t` runner is now checked as `3.13t`.        |
| `feu>=0.9.0` is required                                          | None (the action installs it).                                          |
| New input `invalid-version-mode` (additive, default keeps `skip`) | Set `fail` to replace the manual follow-up step.                        |

## 5. Decisions

1. **Wildcards**: keep, checked by `feu>=0.9.0` (verified, section 2.3). Replaces the earlier
   "drop" answer, which was based on the dry-run alternative.
2. **Private indexes**: (a) document that the check ignores `uv-args`. Add a skip-the-check option
   (b) only if users ask.
3. **`installed` output**: keep.
4. **`invoke` vs `make`**: nothing depends on `tasks.py`; remove it.

5. **Stable `feu`**: `v0.3.0` is released only once `feu 0.9.0` is stable. It now is, and the
   action requires `feu>=0.9.0,<1`.
6. **`installed-version` output**: add it. Produced by step 3.2 with `uv pip show`, so it reports
   what is really in the environment, which matters for wildcards.

## 6. Migration plan (one PR per item, each branched from `main`)

1. `refactor/split-input-validation`: `check_uv.sh`, `validate_inputs.sh` (name, version, mode),
   `validate_python_version.sh` (no normalization), their bats files, steps 1.1 to 1.3. Fixes A9.
2. `refactor/check-version-with-feu-0-9`: install `feu[cli,requests]>=0.9.0a0`, new
   `check_version.sh`, drop the retry loop and the wildcard script, delegate Python detection. Fixes
   A1, A2, A4, A5, A10.
3. `feat/add-invalid-version-mode`: `invalid-version-mode`, `handle_invalid_version.sh`, README
   update. Fixes A6.
4. `refactor/remove-import-check`: remove step 7, `get_import_name.sh`, rename the output, remove
   the metacharacter warning. Fixes A3, A7.
5. `docs/rewrite-readme`: matrix use case, venv prerequisite, behaviour matrix, shorter
   troubleshooting; update `tests/TESTING.md`. Fixes A8.
6. `ci/table-driven-edge-cases`: matrix-driven edge cases, output assertions, export-set check.
7. `chore/repo-hygiene`: `.gitattributes`, empty `tests/unit`, invoke removal. Fixes A11.
8. Release `v0.3.0` (`feu 0.9.0` is stable and the pin is `feu>=0.9.0,<1`).

Expected result: five small scripts instead of four, seven steps that each do one thing, no retry
loop, no import guess, and `feu` as the only extra package in the environment.

## 7. Checks for each PR

Per `CLAUDE.md`: `make format`, `make lint`, `bats tests/bats/` (also with bash 3.2 on macOS),
`pytest`, and `git archive --worktree-attributes HEAD | tar t`. The `ci-action*` and nightly
workflows run only on GitHub, so each PR must say they were not run locally and that CI was not
awaited.
