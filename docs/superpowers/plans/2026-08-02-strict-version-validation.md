# Strict Version Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the action's "auto-resolve closest version" behavior with a strict check: install the requested `package-version` only if `feu check-valid-version` reports it valid, otherwise skip install/verify and expose that fact via a new `is-valid-version` output, without failing the step.

**Architecture:** This is a composite GitHub Action (`action.yaml`, bash `run:` steps). The change swaps the "Find closest valid version" step for a "Check version validity" step that calls a different `feu` subcommand and captures a boolean output, then gates the existing "Install package" and "Verify installation" steps on that output via `if:`.

**Tech Stack:** GitHub Actions composite action YAML, bash, `feu` CLI (`feu[cli]>=0.8.0a0,<1.0`, already installed by the action), `uv`.

## Global Constraints

- `package-name`, `package-version`, `python-version`, `uv-args` inputs stay exactly as-is (required/optional, same semantics, same descriptions) — per spec.
- `feu check-valid-version` always exits 0 and prints the literal string `True` or `False` to stdout (verified interactively: `python -m feu check-valid-version --pkg-name=numpy --pkg-version=2.0.2 --python-version=3.10` → `True`; with `--pkg-version=999.999.999` → `False`).
- No hard workflow stop is implemented inside the action; the invalid case exits 0 with a `::warning::` and `is-valid-version=false`. Consumers who want a hard stop add their own `if:` step — this pattern must be documented in the README.
- `find-closest-version` must not be called anywhere after this change.

---

### Task 1: Replace version resolution with strict validity check in `action.yaml`

**Files:**
- Modify: `action.yaml:28-35` (outputs block)
- Modify: `action.yaml:170-225` (Step 5, "Find closest valid version" → "Check version validity")
- Modify: `action.yaml:226-253` (Step 6, "Install package" — add `if:` gate, use `inputs.package-version` directly)
- Modify: `action.yaml:255-287` (Step 7, "Verify installation" — add `if:` gate)
- Modify: `action.yaml:1-4` (top-level `description:`)

**Interfaces:**
- Produces: step id `check-version` with output `is-valid-version` (string `'true'`/`'false'`), consumed by the `if:` conditions on `install-package` and the verify step, and re-exposed as the action-level output `is-valid-version`.
- Consumes: `steps.validate-python-version.outputs.normalized-python-version` (unchanged, from existing Step 3).

- [ ] **Step 1: Update the top-level action description**

Edit `action.yaml:1-4`:

```yaml
name: 'uv-install-package'
description: |
  Install Python packages with uv, validating that the requested version is
  installable for your target Python environment via PyPI before installing.
```

- [ ] **Step 2: Replace the outputs block**

Edit `action.yaml:28-35` from:

```yaml
outputs:
  closest-valid-version:
    description: 'The closest valid package version that matches your constraints and is compatible with the specified Python version'
    value: ${{ steps.find-version.outputs.closest-valid-version }}
  installed-successfully:
    description: 'Boolean indicating whether the package was installed successfully'
    value: ${{ steps.install-package.outcome == 'success' }}
```

to:

```yaml
outputs:
  is-valid-version:
    description: 'Boolean indicating whether the requested package-version is valid and installable for the target Python version (true or false)'
    value: ${{ steps.check-version.outputs.is-valid-version }}
  installed-successfully:
    description: 'Boolean indicating whether the package was installed successfully'
    value: ${{ steps.install-package.outcome == 'success' }}
```

- [ ] **Step 3: Replace Step 5 ("Find closest valid version") with "Check version validity"**

Edit `action.yaml:170-225` (the full step, comment block included) from:

```yaml
    # ============================================================================
    # Step 5: Find the closest valid package version
    # ============================================================================
    # Query PyPI to find the closest available version that matches:
    # - The requested package version (exact or range)
    # - Compatibility with the specified Python version
    # This prevents installation failures from incompatible versions.
    - name: Find closest valid version
      id: find-version
      shell: bash
      env:
        PACKAGE_NAME: ${{ inputs.package-name }}
        PACKAGE_VERSION: ${{ inputs.package-version }}
        NORMALIZED_PYTHON_VERSION: ${{ steps.validate-python-version.outputs.normalized-python-version }}
      run: |
        set -euo pipefail

        echo "🔎 Searching for closest valid version..."
        echo "  📦 Package: $PACKAGE_NAME"
        echo "  🎯 Target version: $PACKAGE_VERSION"
        echo "  🐍 Python version: $NORMALIZED_PYTHON_VERSION"

        # Run feu to resolve the closest compatible version
        if ! VERSION=$(python -m feu find-closest-version \
          --pkg-name="$PACKAGE_NAME" \
          --pkg-version="$PACKAGE_VERSION" \
          --python-version="$NORMALIZED_PYTHON_VERSION" 2>&1); then
          echo "::error::❌ Failed to query PyPI for package '$PACKAGE_NAME'."
          echo "::error::Possible causes:"
          echo "::error::  - Package name is incorrect (verify on https://pypi.org/)"
          echo "::error::  - Network connectivity issues"
          echo "::error::  - PyPI is temporarily unavailable"
          echo "::error::  - Custom index (via uv-args) is not accessible"
          exit 1
        fi

        # Validate that we got a version back
        if [ -z "$VERSION" ]; then
          echo "::error::❌ No compatible version found for package '$PACKAGE_NAME' version '$PACKAGE_VERSION' with Python $NORMALIZED_PYTHON_VERSION"
          echo "::error::Suggestions:"
          echo "::error::  - Check if the package supports Python $NORMALIZED_PYTHON_VERSION on PyPI"
          echo "::error::  - Try a different package version"
          echo "::error::  - Try a different Python version"
          exit 1
        fi

        # Validate version format (should be digits.digits.digits or similar)
        if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)*$'; then
          echo "::error::❌ Invalid version format returned: '$VERSION'"
          exit 1
        fi

        echo "✅ Found closest valid version: $VERSION"
        # Export the version for use in subsequent steps
        echo "closest-valid-version=$VERSION" >> "$GITHUB_OUTPUT"
```

with:

```yaml
    # ============================================================================
    # Step 5: Check requested version validity
    # ============================================================================
    # Query PyPI (via feu) to check whether the exact requested package
    # version is installable for the target Python version. Unlike the
    # previous behavior, no substitute version is resolved: the action
    # either installs exactly what was requested, or skips installation.
    - name: Check version validity
      id: check-version
      shell: bash
      env:
        PACKAGE_NAME: ${{ inputs.package-name }}
        PACKAGE_VERSION: ${{ inputs.package-version }}
        NORMALIZED_PYTHON_VERSION: ${{ steps.validate-python-version.outputs.normalized-python-version }}
      run: |
        set -euo pipefail

        echo "🔎 Checking version validity..."
        echo "  📦 Package: $PACKAGE_NAME"
        echo "  🎯 Requested version: $PACKAGE_VERSION"
        echo "  🐍 Python version: $NORMALIZED_PYTHON_VERSION"

        # Run feu to check whether the requested version is valid
        if ! RESULT=$(python -m feu check-valid-version \
          --pkg-name="$PACKAGE_NAME" \
          --pkg-version="$PACKAGE_VERSION" \
          --python-version="$NORMALIZED_PYTHON_VERSION" 2>&1); then
          echo "::error::❌ Failed to query PyPI for package '$PACKAGE_NAME'."
          echo "::error::Possible causes:"
          echo "::error::  - Package name is incorrect (verify on https://pypi.org/)"
          echo "::error::  - Network connectivity issues"
          echo "::error::  - PyPI is temporarily unavailable"
          echo "::error::  - Custom index (via uv-args) is not accessible"
          exit 1
        fi

        if [ "$RESULT" = "True" ]; then
          echo "✅ Version '$PACKAGE_VERSION' is valid for Python $NORMALIZED_PYTHON_VERSION"
          echo "is-valid-version=true" >> "$GITHUB_OUTPUT"
        elif [ "$RESULT" = "False" ]; then
          echo "::warning::⚠️  Version '$PACKAGE_VERSION' of '$PACKAGE_NAME' is not valid for Python $NORMALIZED_PYTHON_VERSION. Skipping installation."
          echo "is-valid-version=false" >> "$GITHUB_OUTPUT"
        else
          echo "::error::❌ Unexpected output from feu check-valid-version: '$RESULT'"
          exit 1
        fi
```

- [ ] **Step 4: Gate the "Install package" step and drop the closest-version indirection**

Edit `action.yaml:226-253` (the full step) from:

```yaml
    # ============================================================================
    # Step 6: Install the resolved package version
    # ============================================================================
    # Use feu's installer wrapper to install the package with uv.
    # This ensures consistent installation behavior and proper handling of
    # any additional uv arguments passed by the user.
    - name: Install package
      id: install-package
      shell: bash
      env:
        PACKAGE_NAME: ${{ inputs.package-name }}
        UV_ARGS: ${{ inputs.uv-args }}
        CLOSEST_VERSION: ${{ steps.find-version.outputs.closest-valid-version }}
      run: |
        set -euo pipefail

        echo "📥 Installing package..."
        echo "  📦 Package: $PACKAGE_NAME"
        echo "  🏷️  Version: $CLOSEST_VERSION"

        # Install the package using feu's installer wrapper
        python -m feu install \
          --installer-name=uv \
          --installer-args="$UV_ARGS" \
          --pkg-name="$PACKAGE_NAME" \
          --pkg-version="$CLOSEST_VERSION"

        echo "::notice::✅ Successfully installed ${PACKAGE_NAME}==${CLOSEST_VERSION}"
```

with:

```yaml
    # ============================================================================
    # Step 6: Install the requested package version
    # ============================================================================
    # Use feu's installer wrapper to install the package with uv, only if
    # Step 5 confirmed the requested version is valid.
    - name: Install package
      id: install-package
      if: steps.check-version.outputs.is-valid-version == 'true'
      shell: bash
      env:
        PACKAGE_NAME: ${{ inputs.package-name }}
        PACKAGE_VERSION: ${{ inputs.package-version }}
        UV_ARGS: ${{ inputs.uv-args }}
      run: |
        set -euo pipefail

        echo "📥 Installing package..."
        echo "  📦 Package: $PACKAGE_NAME"
        echo "  🏷️  Version: $PACKAGE_VERSION"

        # Install the package using feu's installer wrapper
        python -m feu install \
          --installer-name=uv \
          --installer-args="$UV_ARGS" \
          --pkg-name="$PACKAGE_NAME" \
          --pkg-version="$PACKAGE_VERSION"

        echo "::notice::✅ Successfully installed ${PACKAGE_NAME}==${PACKAGE_VERSION}"
```

- [ ] **Step 5: Gate the "Verify installation" step**

Edit `action.yaml:255-260` (just the step header, body unchanged) from:

```yaml
    # ============================================================================
    # Step 7: Verify package installation
    # ============================================================================
    # Verify that the installed package can be imported successfully.
    # This catches issues where installation succeeded but the package is broken.
    - name: Verify installation
      shell: bash
```

to:

```yaml
    # ============================================================================
    # Step 7: Verify package installation
    # ============================================================================
    # Verify that the installed package can be imported successfully.
    # This catches issues where installation succeeded but the package is broken.
    # Skipped when Step 5 found the requested version invalid (nothing was installed).
    - name: Verify installation
      if: steps.check-version.outputs.is-valid-version == 'true'
      shell: bash
```

- [ ] **Step 6: Lint the action YAML**

Run:
```bash
actionlint action.yaml
yamllint action.yaml
```
Expected: no errors from either tool. (If `yamllint` flags pre-existing unrelated style issues, confirm they also exist on `main` via `git stash` and are not introduced by this change.)

- [ ] **Step 7: Manually exercise both `feu` code paths this step depends on**

Run, to confirm the exact stdout format the new step's `if` branches rely on:
```bash
python -m feu check-valid-version --pkg-name=numpy --pkg-version=2.0.2 --python-version=3.10
python -m feu check-valid-version --pkg-name=numpy --pkg-version=999.999.999 --python-version=3.10
```
Expected: `True` then `False`, each on their own line, exit code 0 both times.

- [ ] **Step 8: Commit**

```bash
git add action.yaml
git commit -m "feat: replace closest-version auto-resolve with strict version validation"
```

---

### Task 2: Update `README.md` for the new behavior

**Files:**
- Modify: `README.md:29-38` (Overview)
- Modify: `README.md:105-120` (Use Output Version example)
- Modify: `README.md:131-136` (Outputs table)
- Modify: `README.md:138-164` (How It Works + Example Scenario)
- Modify: `README.md:200-208` ("No compatible version found" troubleshooting entry)

**Interfaces:**
- Consumes: the `is-valid-version` output name and semantics defined in Task 1 Step 2.
- Produces: none (documentation only).

- [ ] **Step 1: Update the Overview section**

Edit `README.md:29-38` from:

```markdown
GitHub Action to install Python packages with uv, automatically finding compatible versions for your
target Python environment.

## Overview

This action helps you install Python packages reliably by:

1. Finding the closest compatible version for your Python environment
2. Installing the package using the fast [uv](https://github.com/astral-sh/uv) package installer
3. Handling version compatibility automatically via PyPI metadata
```

to:

```markdown
GitHub Action to install Python packages with uv, validating that the requested version is
installable for your target Python environment before installing.

## Overview

This action helps you install Python packages reliably by:

1. Checking whether the requested version is valid for your Python environment (via PyPI metadata)
2. Installing the package using the fast [uv](https://github.com/astral-sh/uv) package installer, only if the version is valid
3. Skipping installation (without failing the step) when the requested version is invalid, and reporting that via the `is-valid-version` output
```

- [ ] **Step 2: Update the "Use Output Version" example**

Edit `README.md:105-120` from:

```markdown
### Use Output Version

```yaml
  - name: Install and capture version
    id: install
    uses: durandtibo/uv-install-package-action@v0.1.3
    with:
      package-name: 'torch'
      package-version: '2.0.0'
      python-version: '3.11'

  - name: Display installed version
    run: |
      echo "Installed torch version: ${{ steps.install.outputs.closest-valid-version }}"
      echo "Installation successful: ${{ steps.install.outputs.installed-successfully }}"
```
```

to:

```markdown
### Use Output Version and Stop the Workflow on Invalid Versions

```yaml
  - name: Install and check validity
    id: install
    uses: durandtibo/uv-install-package-action@v0.1.3
    with:
      package-name: 'torch'
      package-version: '2.0.0'
      python-version: '3.11'

  - name: Display result
    run: |
      echo "Version valid: ${{ steps.install.outputs.is-valid-version }}"
      echo "Installation successful: ${{ steps.install.outputs.installed-successfully }}"

  # Optional: the action itself never fails the job on an invalid version.
  # Add this step if you want the workflow to stop when the version is invalid.
  - name: Stop workflow on invalid version
    if: steps.install.outputs.is-valid-version != 'true'
    run: exit 1
```
```

- [ ] **Step 3: Update the Outputs table**

Edit `README.md:131-136` from:

```markdown
## Outputs

| Name                     | Description                                                                                                         |
|--------------------------|---------------------------------------------------------------------------------------------------------------------|
| `closest-valid-version`  | The closest valid package version that matches your constraints and is compatible with the specified Python version |
| `installed-successfully` | Boolean indicating whether the package was installed successfully (`true` or `false`)                               |
```

to:

```markdown
## Outputs

| Name                     | Description                                                                                            |
|--------------------------|---------------------------------------------------------------------------------------------------------|
| `is-valid-version`       | Boolean indicating whether the requested `package-version` is valid and installable for the target Python version (`true` or `false`) |
| `installed-successfully` | Boolean indicating whether the package was installed successfully (`true` or `false`)                  |
```

- [ ] **Step 4: Update "How It Works" and "Example Scenario"**

Edit `README.md:138-164` from:

```markdown
## How It Works

This action uses [feu](https://github.com/durandtibo/feu) (Find Compatible Version Utility) to
intelligently resolve and install Python packages:

1. **Verify prerequisites** - Check that `uv` package manager is installed and accessible
2. **Validate inputs** - Ensure package name and version are provided and properly formatted
3. **Normalize Python version** - Validate and normalize Python version (e.g., `3.10.1` → `3.10`)
4. **Install feu** - Install the version resolution utility with automatic retry on network failures
5. **Query PyPI** - Find all available versions and filter by Python compatibility
6. **Select best match** - Choose the closest version that matches your constraints
7. **Install package** - Use `uv` to install the resolved version with your custom arguments
8. **Verify installation** - Confirm the package can be imported successfully

This multi-step approach ensures reliability and provides clear feedback at each stage, making
troubleshooting easier.

### Example Scenario

If you request `numpy==2.0.0` with Python 3.9, but numpy 2.0.0 requires Python ≥3.10:

- The action validates your inputs and Python version format
- Queries PyPI for compatible numpy versions
- Finds the closest compatible version (e.g., `1.26.4`)
- Installs that version instead
- Verifies the package imports correctly
- Reports `1.26.4` as the `closest-valid-version` output
```

to:

```markdown
## How It Works

This action uses [feu](https://github.com/durandtibo/feu) (Find Compatible Version Utility) to
validate and install Python packages:

1. **Verify prerequisites** - Check that `uv` package manager is installed and accessible
2. **Validate inputs** - Ensure package name and version are provided and properly formatted
3. **Normalize Python version** - Validate and normalize Python version (e.g., `3.10.1` → `3.10`)
4. **Install feu** - Install the version resolution utility with automatic retry on network failures
5. **Check version validity** - Query PyPI to check whether the exact requested version is
   installable for the target Python version
6. **Install package** - If valid, use `uv` to install exactly the requested version with your
   custom arguments; if invalid, skip installation and report `is-valid-version=false`
7. **Verify installation** - If a package was installed, confirm it can be imported successfully

This action never auto-substitutes a different version, and it does not fail the job when the
requested version is invalid — it exits successfully with `is-valid-version=false` so your
workflow can decide what to do next (see [Use Output Version and Stop the Workflow on Invalid
Versions](#use-output-version-and-stop-the-workflow-on-invalid-versions)).

### Example Scenario

If you request `numpy==2.0.0` with Python 3.9, but numpy 2.0.0 requires Python ≥3.10:

- The action validates your inputs and Python version format
- Queries PyPI to check whether `numpy==2.0.0` is installable for Python 3.9
- Finds that it is not valid for Python 3.9
- Skips installation and skips the import verification step
- Emits a `::warning::` explaining why installation was skipped
- Reports `false` as the `is-valid-version` output, and the job still succeeds
```

- [ ] **Step 5: Update the "No compatible version found" troubleshooting entry**

Edit `README.md:200-208` from:

```markdown
### Error: "No compatible version found"

This happens when no version of the package is compatible with your Python version.

**Solutions:**

- Check the package's Python version requirements on PyPI
- Try a different Python version
- Try an older version of the package that supports your Python version
```

to:

```markdown
### Warning: "Version is not valid for Python X.Y. Skipping installation."

This happens when the requested `package-version` is not installable for your target
`python-version`. The action does not fail the job — it skips installation and reports
`is-valid-version=false`.

**Solutions:**

- Check the package's Python version requirements on PyPI
- Try a different `python-version`
- Try a different `package-version` that supports your Python version
- If you want the workflow to stop in this case, add a follow-up step that checks
  `is-valid-version` and exits non-zero (see [Use Output Version and Stop the Workflow on
  Invalid Versions](#use-output-version-and-stop-the-workflow-on-invalid-versions))
```

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: document strict version validation behavior"
```

---

### Task 3: Update tests and fixtures referencing the old outputs/behavior

**Files:**
- Modify: `tests/functional/test_package.py` (only if it references `closest-valid-version` or old step ids — inspect first)
- Modify: `.github/workflows/test-local-action.yaml` and any other workflow YAML under `.github/workflows/` that references `closest-valid-version` or `find-version` (grep first; expected: none found beyond README, but verify)

**Interfaces:**
- Consumes: `is-valid-version` output name from Task 1.

- [ ] **Step 1: Grep the whole repo for now-removed identifiers**

Run:
```bash
grep -rn "closest-valid-version\|find-version\|find-closest-version" --include="*.yaml" --include="*.yml" --include="*.py" --include="*.sh" --include="*.bats" . | grep -v docs/superpowers
```
Expected: only the lines inside `action.yaml`/`README.md` already changed in Tasks 1–2 (should be empty after those tasks land — if this still shows hits, note the file/line for the next step).

- [ ] **Step 2: Fix any remaining hits found in Step 1**

For each remaining hit outside `action.yaml`/`README.md`, open the file, and replace the reference:
- `closest-valid-version` → `is-valid-version` (adjust surrounding logic if it compared against a version string rather than a boolean — flag to the user if a file does this in a way that doesn't map cleanly, rather than guessing).
- `find-version`/`find-closest-version` → `check-version`/`check-valid-version` respectively.

- [ ] **Step 3: Re-run the grep from Step 1 to confirm it's clean**

Run the same command as Step 1.
Expected: no output (or only comments/docs referencing the old behavior intentionally, e.g. a CHANGELOG — leave those untouched).

- [ ] **Step 4: Run the existing shell and Python test suites**

Run:
```bash
bats --recursive tests/bats/
pytest tests/unit/ tests/functional/ -k "not (torch or numpy or pandas)" --collect-only
```
Expected: BATS tests pass unchanged (none of them cover `action.yaml`'s new step directly — they test the standalone `scripts/*.sh`, which are untouched by this change). The pytest collect-only run confirms no import/collection errors were introduced; skip actually running functional tests here since they require installed packages not relevant to this change.

- [ ] **Step 5: Commit (only if Step 2 produced changes)**

```bash
git add -A
git commit -m "test: update references to renamed check-valid-version output"
```
If Step 1/3 found nothing to fix, skip this commit — there's nothing to record.
