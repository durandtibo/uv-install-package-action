# uv-install-package

[![CI](https://github.com/durandtibo/uv-install-package-action/actions/workflows/ci.yaml/badge.svg)](https://github.com/durandtibo/uv-install-package-action/actions/workflows/ci.yaml)
[![Nightly](https://github.com/durandtibo/uv-install-package-action/actions/workflows/nightly.yaml/badge.svg)](https://github.com/durandtibo/uv-install-package-action/actions/workflows/nightly.yaml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/durandtibo/uv-install-package-action/badge)](https://scorecard.dev/viewer/?uri=github.com/durandtibo/uv-install-package-action)
[![License](https://img.shields.io/badge/license-BSD--3--Clause-blue)](LICENSE)
[![Latest release](https://img.shields.io/github/v/tag/durandtibo/uv-install-package-action?label=release)](https://github.com/durandtibo/uv-install-package-action/tags)

GitHub Action to install a Python package with [uv](https://github.com/astral-sh/uv), but only
when the requested version is valid for the target Python version.

> **Note:** this page documents the version in development (`v0.3.0`, not released yet). For
> `v0.2.0`, read the README of that tag.

## Overview

The action is designed for **matrix jobs** (Python version × OS × package version). In such a
matrix it is hard to list by hand which package versions work with which Python version (for
example 3.13 vs 3.14 vs 3.15). The action answers "is this version usable here?" so the workflow
can stay a plain cross product, and the invalid cells skip cleanly (or fail, on request).

It checks the requested version with [feu](https://github.com/durandtibo/feu), which holds curated
version ranges per package and Python version, then installs it with `uv`. `feu` is installed by the
action. An exact version is never replaced by another one, and a wildcard such as `2.12.*` installs
the newest valid release matching it.

## Prerequisites

- **uv** must be available, for example with
  [astral-sh/setup-uv](https://github.com/astral-sh/setup-uv).
- `uv pip install` needs an environment to install into: either activate a virtual environment
  (`activate-environment: true` in `setup-uv`) or set `UV_SYSTEM_PYTHON=1`.
- Linux and macOS runners (GitHub-hosted or self-hosted) are supported. Windows is not.

## Usage

### Matrix of Python and package versions

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        python-version: ["3.11", "3.12", "3.13", "3.14"]
        numpy-version: ["1.26.4", "2.2.*", "2.3.*"]
    steps:
      - uses: actions/checkout@v6

      - uses: astral-sh/setup-uv@v7
        with:
          python-version: ${{ matrix.python-version }}
          activate-environment: true

      - name: Install numpy
        id: numpy
        uses: durandtibo/uv-install-package-action@v0.3.0
        with:
          package-name: numpy
          package-version: ${{ matrix.numpy-version }}
          python-version: ${{ matrix.python-version }}

      - name: Run tests
        if: steps.numpy.outputs.installed == 'true'
        run: pytest
```

The cells where the numpy version does not support the Python version are skipped with a warning
instead of failing.

### Basic example

```yaml
steps:
  - uses: astral-sh/setup-uv@v7
    with:
      python-version: "3.12"
      activate-environment: true

  - uses: durandtibo/uv-install-package-action@v0.3.0
    with:
      package-name: numpy
      package-version: "2.0.2"
```

`python-version` is optional: `feu` uses the Python interpreter of the environment.

### Fail on an invalid version

```yaml
- name: Install torch
  id: torch
  uses: durandtibo/uv-install-package-action@v0.3.0
  with:
    package-name: torch
    package-version: "2.0.0"
    invalid-version-mode: fail

- name: Show the result
  run: echo "Installed ${{ steps.torch.outputs.installed-version }}"
```

### Custom index

```yaml
- uses: durandtibo/uv-install-package-action@v0.3.0
  with:
    package-name: my-package
    package-version: "1.0.0"
    uv-args: "--index-url https://pypi.example.com/simple"
```

`uv-args` is split with `shlex`, so quoted arguments work. It applies to the install only, not to
the version check (see [Limitations](#limitations)).

## Inputs

| Name                   | Required | Default       | Description                                                                                                                                                                      |
| ---------------------- | -------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `package-name`         | Yes      | -             | Distribution name (e.g. `numpy`). Must be a valid package name.                                                                                                                  |
| `package-version`      | Yes      | -             | Exact version (`2.0.2`) or wildcard (`2.12.*`).                                                                                                                                  |
| `python-version`       | No       | auto-detected | Target Python: `X.Y` or free-threaded `X.Yt` (e.g. `3.13t`). Patch versions such as `3.12.1` are rejected. When empty, `feu` uses the interpreter the package is installed into. |
| `invalid-version-mode` | No       | `skip`        | `skip`: warn, install nothing and succeed. `fail`: fail the job. Any other value is an input error.                                                                              |
| `uv-args`              | No       | `""`          | Extra arguments for `uv pip install` (e.g. `--index-url https://...`), parsed with `shlex`.                                                                                      |

## Outputs

| Name                | Description                                                                                   |
| ------------------- | --------------------------------------------------------------------------------------------- |
| `is-valid-version`  | `true` or `false`: result of the check, for exact versions and wildcards.                     |
| `installed`         | `true` if the package was installed, `false` if the installation was skipped.                 |
| `installed-version` | Version actually installed (e.g. `2.3.5` for `2.3.*`), empty if the installation was skipped. |

## Behavior

| Situation                             | Result                                                              |
| ------------------------------------- | ------------------------------------------------------------------- |
| Valid version                         | Installs. `is-valid-version=true`, `installed=true`.                |
| Invalid version, `skip` mode          | Warning, nothing installed, `false` / `false`, the job succeeds.    |
| Invalid version, `fail` mode          | `::error::`, the job fails (`is-valid-version=false` is still set). |
| Bad input, uv missing, feu cannot run | `::error::`, the job fails (never reported as an invalid version).  |
| Install fails                         | The job fails, the output of `uv` is visible.                       |

A wildcard that matches no valid release counts as an invalid version.

## Limitations

- The check does not use `uv-args`: exact versions are checked against the table of `feu`, and
  wildcards against the release list of the default PyPI index (which needs network access), even
  if `uv-args` sets another index.
- A package that is not in the table of `feu` is always considered valid. A typo in `package-name`
  is caught by the install step, with the error of `uv`.
- The action requires `feu>=0.9.0a0` (a pre-release, installed by the action).
- Windows is not supported.

## What's new

Please refer to the [release page](https://github.com/durandtibo/uv-install-package-action/releases)
for the release notes. Releases are immutable exact version tags (e.g. `v0.2.0`).

## Suggestions and Communication

Everyone is welcome to contribute to the community.
If you have any questions or suggestions, you can
submit [Github Issues](https://github.com/durandtibo/uv-install-package-action/issues).
We will reply to you as soon as possible. Thank you very much.

## License

`uv-install-package-action` is licensed under BSD 3-Clause "New" or "Revised" license available
in [LICENSE](LICENSE) file.
