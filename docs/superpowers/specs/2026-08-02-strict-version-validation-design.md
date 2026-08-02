# Strict Version Validation (replace closest-version auto-resolve)

## Context

Today the action takes `package-name` and `package-version`, then uses
`feu find-closest-version` to silently substitute the closest valid version
if the requested one isn't installable for the target Python version, and
installs that instead.

This is changing to a strict-validation model: check whether the requested
version is valid (still via `feu`, using its `check-valid-version` command),
install it if valid, and skip installation if not — without auto-substituting
anything.

## Behavior

- **Step "Check version validity"** (replaces "Find closest version"):
  runs `python -m feu check-valid-version --pkg-name=<package-name>
  --pkg-version=<package-version> --python-version=<normalized-python-version>`.
  This command always exits 0 and prints the literal string `True` or `False`.
  The step captures that into a new action output `is-valid-version`
  (`'true'` / `'false'`).
- **Step "Install package"**: gated with
  `if: steps.check-version.outputs.is-valid-version == 'true'`. Installs
  `package-name==package-version` exactly as requested (no substituted
  version).
- **Step "Verify installation"**: gated on the same condition, so it's
  skipped when nothing was installed.
- When the version is invalid, the check step emits a `::warning::` (not
  `::error::`) explaining that the requested version is invalid for the
  target Python version and that installation was skipped. The action step
  itself still exits 0 — it does not fail the job.
- The action does not stop the calling workflow by itself. If a consuming
  workflow wants a hard stop, it's the workflow author's responsibility to
  add an `if:` check against `is-valid-version` (or `installed-successfully`)
  on later steps, e.g.:
  ```yaml
  - if: steps.install.outputs.is-valid-version != 'true'
    run: exit 1
  ```
  This pattern will be documented in the README.

## action.yaml changes

- Remove output `closest-valid-version`.
- Add output `is-valid-version`: `'true'`/`'false'`, sourced from the new
  check step.
- Keep output `installed-successfully` — it naturally reflects `false`/step
  skipped when install didn't run.
- Rename step id `find-version` → `check-version`; rename its display name
  from "Find closest version" to "Check version validity".
- Update step "Install package" to reference `inputs.package-version`
  directly instead of `steps.find-version.outputs.closest-valid-version`,
  and add the `if:` gate described above.
- Update step "Verify installation" with the same `if:` gate.

## Out of scope / removed

- `feu find-closest-version` is no longer called anywhere in the action.
- No changes to input contract: `package-name`, `package-version`,
  `python-version`, `uv-args` all stay as-is (required/optional, same
  semantics).
- No changes to the "Verify uv is installed", "Validate inputs", or
  "Validate Python version" steps.

## Testing

- Existing tests under `tests/` that reference `find-closest-version` /
  `closest-valid-version` need to be updated to reflect
  `check-valid-version` / `is-valid-version`.
- Add/update test coverage for: valid version installs normally; invalid
  version skips install and verification steps, action still exits 0, and
  `is-valid-version` output is `'false'`.

## Documentation

- Update `README.md` to describe the new behavior (strict check instead of
  closest-version resolution) and the recommended `if:` pattern for callers
  who want a hard stop on invalid versions.
