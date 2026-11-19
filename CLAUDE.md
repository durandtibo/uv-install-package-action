# CLAUDE.md

Guidance for coding agents working in this repository.

## Repository purpose

A GitHub composite action (`action.yaml`) that installs a Python package with
[uv](https://github.com/astral-sh/uv), first checking (via `feu`) that the requested version is
valid for the target Python version, and skipping installation when it is not. The logic lives in
small bash scripts in `scripts/` (must work on GNU/Linux and BSD/macOS, including the bash 3.2 of
macOS; Windows is not supported and not tested) tested with
[bats](https://github.com/bats-core/bats-core) in `tests/bats/`. `tests/functional/` holds pytest
tests, `tests/action_cases.json` the edge cases of the action tests, and `dev/` holds maintainer
helpers (`check_export.sh`, `check_action_case.sh`, `check_bats_assertions.sh`,
`generate_versions.py`, `config/`), not part of
the action. `review/target_state.md` records the properties (P1 to P11) the action is
judged against, and `review/testing.md` the testing strategy shared by the action repositories
(properties T1 to T16).

## Environment

- Use the `Makefile`; run `make help` to list targets.
- Do not edit `.make/`: it is a shared directory synced by `bot-sync-shared-makefile.yaml`.
- Run `make format` and `make lint` before committing. Fix what they report instead of disabling
  rules.
- Run the shell tests with `bats tests/bats/` (install `bats-core` if missing) and the Python tests
  with `pytest`, or both with `make test`. See `tests/TESTING.md`. Check the release archive with
  `make check-export`, and the bats assertions with `make check-bats-assertions`. Some workflows
  cannot be run locally; say so in the PR instead of claiming
  they pass.

## Git workflow

- One branch and one PR per logical change, branched from an up-to-date `main`. Never commit or
  push to `main`.
- Name branches `<type>/<short-description>` in kebab-case, with type one of: `feat`, `bugfix`,
  `hotfix`, `docs`, `refactor`, `perf`, `test`, `chore`, `ci`.
- Write commit messages and PR titles as a short imperative sentence starting with a verb such as
  `Add`, `Fix`, `Update`, `Remove` or `Improve`. Do not use conventional-commit prefixes like
  `docs:` or `feat:` (the type prefix is only for branch names). The squash-merge appends the PR
  number, so do not add one.
- PR descriptions cover what changed, what was deliberately left alone, and any behaviour change.
- Do not escape special characters such as the backtick (`` ` ``) in PR titles and descriptions
  (no `\``): the escape characters are not rendered well. Write them as plain Markdown.
- On conflicts with `main`, merge `origin/main` into the branch; do not rebase and force-push.
- Update `README.md` when inputs, outputs, behaviour, or workflows change.
- Releases are immutable exact version tags (`v0.2.0`, ...). Do not create or move floating tags
  (`v0`, `latest`) and do not document them as an option.

## Action rules (`action.yaml`)

- Keep input/output names, defaults, and descriptions consistent with `README.md`. Renaming or
  removing an input or output is a breaking change and must be flagged.
- Pass inputs to scripts through `env:`, never by interpolating them in `run:`.
- Every `run:` step sets `shell: bash` and starts with `set -euo pipefail`.
- Keep the numbered step comments (`Step N: ...`) accurate when adding, removing or reordering steps.
- Pin third-party actions in workflows to commit SHAs with a `# ratchet:<owner>/<repo>@<tag>`
  comment, never to tags or branches.
- Workflows use least-privilege `permissions` and set `timeout-minutes` on jobs.
- Only ship what the action needs at runtime: files the action itself uses (`action.yaml`,
  `LICENSE`, the scripts it calls in `scripts/`) are exported, and `.gitattributes` marks everything
  else `export-ignore`. When the action starts using a new file, un-ignore it there, and add any
  new top-level file or directory to `.gitattributes`. Never make the action read tests, fixtures or
  other repo files that are not exported. Check the exported set with
  `git archive --worktree-attributes HEAD | tar t`.

## Shell script rules (`scripts/*.sh`)

- Must stay portable between GNU and BSD tools (`sed`, `xargs`, etc.).
- Must run with the bash 3.2 of macOS: no associative arrays, `mapfile`, `${var,,}` or other
  bash 4+ features (`ci-shell-bash32.yaml` checks it).
- Keep logic in small single-purpose scripts so each can be unit tested. `action.yaml` calls them
  through `${{ github.action_path }}/scripts/`, so a new script goes in `scripts/` with its bats
  file.
- Validate inputs early with clear `::error` messages. A real error (bad input, no uv, network
  failure, failed install) exits non-zero with an `::error`; only an invalid version is skipped,
  and only in `skip` mode.
- Exit with an explicit status on every failure path (`exit 1`); never rely on `set -e` alone.
- Quote all variables.
- Code must pass `shellcheck` and `shfmt` via `make lint` / `make format`.

## Workflow structure (`.github/workflows/`)

Files are prefixed by role:

- `ci.yaml`: entry point for pull requests, pushes to `main`, a nightly schedule and manual runs. It
  holds no steps, only jobs that call the reusable `ci-*.yaml` workflows below.
  - `ci-format.yaml`, `ci-pre-commit.yaml`: format and lint checks (`make format`, `make lint`,
    `make check-python`, `make pre-commit`), and the bats-assertion check
    (`make check-bats-assertions`, `dev/check_bats_assertions.sh`).
  - `ci-shell.yaml`: bats tests on Linux and macOS.
  - `ci-shell-bash32.yaml`: bats tests with the system bash 3.2 of macOS.
  - `ci-export.yaml`: checks the exported set (`make check-export`, `dev/check_export.sh`).
  - `ci-python.yaml`: Python tests.
  - `ci-action.yaml`: tests the action in a real workflow, with the input `use-released`
    (default `false`): the action from this checkout (`uses: ./`), i.e. the version not released
    yet, or the latest release when `true`. It calls `ci-action-deps.yaml` (one job per optional
    dependency, on the full matrix) and `ci-action-edge-cases.yaml` (a table of edge cases) with
    the same `use-released` input. `ci.yaml` passes `false`.
- `ci-verify-workflows.yaml`: lints the workflow files themselves. It has its own triggers and is not
  called from `ci.yaml`, so it can be a required check.
- `nightly.yaml`: scheduled entry point that loads the test matrix and calls `ci-action.yaml` with
  `use-released: true`, which tests the latest released action on real packages with the same
  cases as `ci.yaml`. It is not part of `ci.yaml`. Update the pinned release in
  `ci-action-deps.yaml` and `ci-action-edge-cases.yaml` when a new version is released.
- `lib-*.yaml`: reusable workflows that load shared data (test matrix, package versions, deps,
  extras); callers pass results down through inputs.
- `bot-*.yaml`: scheduled automation that opens PRs or acts on runs (format files, pin actions,
  update deps, pre-commit autoupdate, generate package versions, sync `.make/`, cancel stale runs).
- `security-*.yaml`: dependency review and OSSF Scorecard.

Conventions:

- Set `permissions` on every job (including jobs that call a reusable workflow). Every workflow
  has `permissions: {}` at the workflow level (it grants nothing), never a grant.
- Each `ci-*` check is a `workflow_call` workflow that also has `workflow_dispatch`, so it can be run
  alone. Add a new check as a new `ci-<name>.yaml` plus a job in `ci.yaml`.
- Put `make` targets in the steps rather than duplicating commands, so local runs and CI match
  (`make test-bats`, `make test-functional`, `make check-python`, `make check-export`, ...). A
  command that CI runs and that has no target gets one in the `Makefile` (never in `.make/`).
- Start each file with a comment saying what it does, and update it when the behaviour changes.

## Tests

- Each script in `scripts/` has its own `tests/bats/test_<script_name>.bats` file.
- Write every `[[ ... ]]` or `! cmd` assertion that is not the last command of a test with
  `|| false`: on bash 3.2 (macOS) it does not fail the test otherwise
  (`make check-bats-assertions` rejects the others).
- One behaviour per test; mock external commands (`uv`, `feu`, ...) rather than calling the network.
- Cover success, failure, and edge cases (empty input, wildcard versions, free-threaded `3.13t`,
  invalid formats).
- Every bug fix needs a regression test that fails without the fix.
- If a check fails for a real reason, report it rather than weakening the test.
- `tests/bats/test_action_readme_sync.bats` compares `action.yaml` and `README.md` (inputs,
  outputs, required flags, defaults) and checks that inputs go through `env:`. Update the README
  with `action.yaml` or it fails.
- Keep `tests/TESTING.md` in step with the test files and workflows.

## Testing strategy

The strategy is the same for all the action repositories of `durandtibo`. The full reasoning and
the properties (T1 to T16) are in `review/testing.md`. This repository follows it with three
levels (`tests/TESTING.md` describes the test files, `review/target_state.md` the properties of the
action they protect):

1. **Code**: each script, tested alone with mocks (bats for `scripts/`, pytest for
   `tests/functional/`). It covers the logic and every edge case. No network.
2. **Local action**: the action from this checkout (`uses: ./`) in a real workflow
   (`ci-action.yaml`).
3. **Released action**: the latest stable release (`uses: durandtibo/uv-install-package-action@<sha>`),
   run nightly with the same cases as level 2 (`nightly.yaml` calls `ci-action.yaml` with
   `use-released: true`). Never run it on pull
   requests.

Rules:

- Test a behaviour at the cheapest level that can show it. The action tests (levels 2 and 3) check
  the contract and the wiring: inputs reach the script, outputs are set, the action fails on an
  invalid input. Do not re-test a script's logic there; add it to level 1.
- Split the action tests in two. **General behaviour** (each optional dependency of the package,
  `ci-action-deps.yaml`) runs on the full matrix: `os_matrix` and `python_versions`. **Edge cases**
  (one input, one invalid value, an unusual Python version) run once on one runner
  (`ci-action-edge-cases.yaml`). The same matrix runs on pull requests, pushes and the schedule;
  there is no reduced matrix.
- Supported equals tested: Linux and macOS and the Python versions of the matrix are tested and
  claimed in the README; Windows is not supported and not tested. Do not claim a platform or a
  Python version that is not in the matrix, and do not leave one in the matrix that the README does
  not claim.
- Never write an OS or a Python version of the matrix in a workflow: read the lists from
  `durandtibo/workflow-config-action` through `lib-get-test-matrix.yaml`. Package versions come
  from `dev/config/package_versions.json` through `lib-get-package-versions.yaml`.
- `ci-action.yaml` and the reusable test workflows it calls take the boolean input `use-released`
  (default `false`) and have two action steps, `uses: ./` with `if: ${{ !inputs.use-released }}`
  and the pinned release with `if: ${{ inputs.use-released }}`. A skipped step has no outputs
  and its outcome is `skipped`, so the verify step reads `steps.<local id>.outputs.x ||
steps.<released id>.outputs.x` and the outcome with `steps.local.outcome == 'skipped' &&
steps.released.outcome || steps.local.outcome`. There is no `nightly-test-released.yaml`: one
  file for both versions, so they cannot drift apart.
- Put the assertions shared by the local and released runs in one verify step per job (or row), not
  in two workflows or two copies. The verify step calls `dev/check_action_case.sh` (tested in
  `tests/bats/test_check_action_case.bats`), which takes the case as JSON and the outputs through
  `env:`.
- Edge cases are data: rows of `tests/action_cases.json`, read by `ci-action-edge-cases.yaml` (a new
  case is a row, not a job; `tests/bats/test_action_cases.bats` checks the table). Set
  `"released": false` on a row until the last release has the feature; the stable run skips it.
- The action tests use the real uv, feu and PyPI, never a fake. The effect of an input is a level 1
  test with mocks.
- Every input has a case with an invalid value that asserts the action failed in the validation: it
  can only fail if the input reached the script, so it proves the wiring. Assert the value or the
  format of outputs (`is-valid-version`, `installed`, `installed-version`), never just print them.
- Failure paths use `continue-on-error: true`, an `id`, and a step that asserts `steps.<id>.outcome`.
  Assert an exact output, not a message. A negative test needs a positive run before it, so it
  cannot pass for the wrong reason.
- Tests have no side effects outside the runner. If something cannot be tested in CI, write down
  which check covers it.
- Check what is shipped: the exported set (`make check-export`) must contain every file the action
  needs, because `uses: ./` runs the whole checkout and hides a missing file.
- Set `timeout-minutes`, `fail-fast: false` and `max-parallel` on matrix jobs (a job that calls a
  reusable workflow cannot set `timeout-minutes`, but still sets `fail-fast` and `max-parallel`).
  Keep the count of cells per run in `tests/TESTING.md` up to date when a matrix changes.
- Keep the README inputs and outputs in step with `action.yaml`
  (`tests/bats/test_action_readme_sync.bats`).

## Reporting

- State which checks ran (`make lint`, `make format`, `bats tests/bats/`, `pytest`,
  `make check-export`, `make check-bats-assertions`) and which did not.
- Note that CI was not awaited.
- Report failures that already exist on `main` rather than hiding them.

## Decisions on the testing strategy

- No mutation check (`cancel-queued-runs-action` has one): `review/testing.md` makes it optional
  and worth it for a script of several hundred lines. The scripts here are 20 to 60 lines, each with
  its own bats file, and the bats-assertion check covers the vacuous-pass risk on bash 3.2.
