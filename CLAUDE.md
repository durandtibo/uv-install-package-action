# CLAUDE.md

Guidance for coding agents working in this repository.

## Repository purpose

A GitHub composite action (`action.yaml`) that installs a Python package with
[uv](https://github.com/astral-sh/uv), first checking (via `feu`) that the requested version is
valid for the target Python version, and skipping installation when it is not. The logic lives in
small bash scripts in `scripts/` (must work on GNU/Linux and BSD/macOS) tested with
[bats](https://github.com/bats-core/bats-core) in `tests/bats/`. `tests/functional/` holds pytest
tests, and `dev/` holds maintainer helpers (`generate_versions.py`, `config/`), not part of the
action.

## Environment

- Use the `Makefile`; run `make help` to list targets.
- Do not edit `.make/`: it is a shared directory synced by `bot-sync-shared-makefile.yaml`.
- Run `make format` and `make lint` before committing. Fix what they report instead of disabling
  rules.
- Run the shell tests with `bats tests/bats/` (install `bats-core` if missing) and the Python tests
  with `pytest`. See `tests/TESTING.md`. Some workflows cannot be run locally; say so in the PR
  instead of claiming they pass.

## Git workflow

- One branch and one PR per logical change, branched from an up-to-date `main`. Never commit or
  push to `main`.
- Name branches `<type>/<short-description>` in kebab-case, with type one of: `feat`, `bugfix`,
  `hotfix`, `docs`, `refactor`, `perf`, `test`, `chore`, `ci`.
- PR descriptions cover what changed, what was deliberately left alone, and any behaviour change.
- On conflicts with `main`, merge `origin/main` into the branch; do not rebase and force-push.
- Update `README.md` when inputs, outputs, behaviour, or workflows change.

## Action rules (`action.yaml`)

- Keep input/output names, defaults, and descriptions consistent with `README.md`. Renaming or
  removing an input or output is a breaking change and must be flagged.
- Pass inputs to scripts through `env:`, never by interpolating them in `run:`.
- Every `run:` step sets `shell: bash` and starts with `set -euo pipefail`.
- Keep the numbered step comments (`Step N: ...`) accurate when adding, removing or reordering steps.
- Pin third-party actions in workflows to commit SHAs with a `# ratchet:<owner>/<repo>@<tag>`
  comment, never to tags or branches.
- Workflows use least-privilege `permissions` and set `timeout-minutes` on jobs.

## Shell script rules (`scripts/*.sh`)

- Must stay portable between GNU and BSD tools (`sed`, `xargs`, etc.).
- Keep logic in small single-purpose scripts so each can be unit tested.
- Quote all variables; validate inputs early with clear error messages.
- Code must pass `shellcheck` and `shfmt` via `make lint` / `make format`.

## Workflow structure (`.github/workflows/`)

Files are prefixed by role:

- `ci.yaml`: entry point for pull requests, pushes to `main`, a nightly schedule and manual runs. It
  holds no steps, only jobs that call the reusable `ci-*.yaml` workflows below.
  - `ci-format.yaml`, `ci-pre-commit.yaml`: format and lint checks.
  - `ci-shell.yaml`: bats tests.
  - `ci-test.yaml`: Python tests.
  - `ci-action.yaml`, `ci-action-edge-cases.yaml`: run the action from this checkout
    (`uses: ./`), i.e. the version not released yet.
  - `ci-action-deps.yaml`: reusable workflow that runs the action.
- `ci-verify-workflows.yaml`: lints the workflow files themselves. It has its own triggers and is not
  called from `ci.yaml`, so it can be a required check.
- `nightly.yaml`: scheduled test of the latest released action on real packages. It is not
  part of `ci.yaml`.
- `lib-*.yaml`: reusable workflows that load shared data (test matrix, package versions, deps,
  extras); callers pass results down through inputs.
- `bot-*.yaml`: scheduled automation that opens PRs or acts on runs (format files, pin actions,
  update deps, pre-commit autoupdate, generate package versions, sync `.make/`, cancel stale runs).
- `security-*.yaml`: dependency review and OSSF Scorecard.

Conventions:

- Set `permissions` explicitly, including on jobs that call a reusable workflow; prefer
  `permissions: {}` at the workflow level and grant only what a job needs.
- Each `ci-*` check is a `workflow_call` workflow that also has `workflow_dispatch`, so it can be run
  alone. Add a new check as a new `ci-<name>.yaml` plus a job in `ci.yaml`.
- Put `make` targets in the steps rather than duplicating commands, so local runs and CI match.
- Start each file with a comment saying what it does, and update it when the behaviour changes.

## Tests

- Each script in `scripts/` has its own `tests/bats/test_<script_name>.bats` file.
- One behaviour per test; mock external commands rather than calling the network.
- Cover success, failure, and edge cases (empty input, wildcard versions, free-threaded `3.13t`,
  invalid formats).
- Every bug fix needs a regression test that fails without the fix.
- If a check fails for a real reason, report it rather than weakening the test.

## Reporting

- State which checks ran (`make lint`, `make format`, `bats tests/bats/`, `pytest`) and which did not.
- Note that CI was not awaited.
- Report failures that already exist on `main` rather than hiding them.
