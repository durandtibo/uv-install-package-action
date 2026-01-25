# uv-install-package

<p align="center">
    <a href="https://github.com/durandtibo/uv-install-package-action/actions">
        <img alt="CI" src="https://github.com/durandtibo/uv-install-package-action/workflows/CI/badge.svg">
    </a>
    <a href="https://github.com/durandtibo/uv-install-package-action/actions">
        <img alt="Nightly Tests" src="https://github.com/durandtibo/uv-install-package-action/workflows/Nightly%20Tests/badge.svg">
    </a>
    <a href="https://github.com/durandtibo/uv-install-package-action/releases">
        <img alt="PYPI version" src="https://img.shields.io/github/v/release/durandtibo/uv-install-package-action?logo=github&sort=semver">
    </a>
    <br/>
    <a href="https://github.com/psf/black">
        <img  alt="Code style: black" src="https://img.shields.io/badge/code%20style-black-000000.svg">
    </a>
    <a href="https://google.github.io/styleguide/pyguide.html#s3.8-comments-and-docstrings">
        <img  alt="Doc style: google" src="https://img.shields.io/badge/%20style-google-3666d6.svg">
    </a>
    <a href="https://github.com/astral-sh/ruff">
        <img src="https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json" alt="Ruff" style="max-width:100%;">
    </a>
    <a href="https://github.com/guilatrova/tryceratops">
        <img  alt="Doc style: google" src="https://img.shields.io/badge/try%2Fexcept%20style-tryceratops%20%F0%9F%A6%96%E2%9C%A8-black">
    </a>
    <br/>
</p>

GitHub Action to install Python packages with uv, automatically finding compatible versions for your target Python environment.

## Overview

This action helps you install Python packages reliably by:
1. Finding the closest compatible version for your Python environment
2. Installing the package using the fast [uv](https://github.com/astral-sh/uv) package installer
3. Handling version compatibility automatically via PyPI metadata

## Prerequisites

This action requires **uv** to be installed and available in your workflow. We recommend using the official [astral-sh/setup-uv](https://github.com/astral-sh/setup-uv) action to install uv.

## What's new

Please refer to
the [release page](https://github.com/durandtibo/uv-install-package-action/releases) for
the latest release notes.

## Usage

### Basic Example

```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@v6

  - name: Install uv
    uses: astral-sh/setup-uv@v7
    with:
      python-version: '3.11'

  - name: Install numpy
    uses: durandtibo/uv-install-package-action@v0.1.1
    with:
      package-name: 'numpy'
      package-version: '2.0.2'
      python-version: '3.11'
```

### Install with Custom PyPI Index

```yaml
  - name: Install package from custom index
    uses: durandtibo/uv-install-package-action@v0.1.1
    with:
      package-name: 'my-package'
      package-version: '1.0.0'
      python-version: '3.12'
      uv-args: '--index-url https://custom.pypi.org/simple'
```

### Use Output Version

```yaml
  - name: Install and capture version
    id: install
    uses: durandtibo/uv-install-package-action@v0.1.1
    with:
      package-name: 'torch'
      package-version: '2.0.0'
      python-version: '3.11'

  - name: Display installed version
    run: |
      echo "Installed torch version: ${{ steps.install.outputs.closest-valid-version }}"
      echo "Installation successful: ${{ steps.install.outputs.installed-successfully }}"
```

## Inputs

| Name               | Description                                                                        | Required | Default |
|--------------------|------------------------------------------------------------------------------------|----------|---------|
| `package-name`     | The package name (e.g., `numpy`, `requests`, `django`)                            | Yes      | -       |
| `package-version`  | The target package version (e.g., `1.2.3`, `2.0.2`)                              | Yes      | -       |
| `python-version`   | The Python version to check compatibility against (e.g., `3.10`, `3.11`, `3.12`). Must be in `X.Y` format. If a patch version is provided (e.g., `3.10.1`), it will be normalized to `X.Y` (e.g., `3.10`). | Yes      | -       |
| `uv-args`          | Additional arguments to pass to uv (e.g., `--index-url https://custom.pypi.org/simple`) | No       | `''`    |

## Outputs

| Name                     | Description                                                                                          |
|--------------------------|------------------------------------------------------------------------------------------------------|
| `closest-valid-version`  | The closest valid package version that matches your constraints and is compatible with the specified Python version |
| `installed-successfully` | Boolean indicating whether the package was installed successfully (`true` or `false`)               |

## How It Works

This action uses [feu](https://github.com/durandtibo/feu) (Find Compatible Version Utility) to:

1. **Query PyPI** for all available versions of the requested package
2. **Filter versions** based on Python version compatibility metadata
3. **Select the closest match** to your requested version that's compatible with your Python version
4. **Install the package** using the fast uv package installer

This ensures you always get a working installation, even if your requested version isn't compatible with your Python version.

### Example Scenario

If you request `numpy==2.0.0` with Python 3.9, but numpy 2.0.0 requires Python ≥3.10:
- The action finds the closest compatible version (e.g., `1.26.4`)
- Installs that version instead
- Reports `1.26.4` as the `closest-valid-version` output

## Troubleshooting

### Error: "Invalid Python version format"

This error occurs when the `python-version` input is not in the expected format.

**Solution:** Use the `X.Y` format for Python version (e.g., `3.10`, `3.11`, `3.12`). If you accidentally provide a patch version (e.g., `3.10.1`), the action will automatically normalize it to `3.10` and show a warning.

Valid formats:
- `3.10` ✅
- `3.11` ✅
- `3.10.1` ✅ (normalized to `3.10`)

Invalid formats:
- `3` ❌
- `python3.10` ❌
- `3.x` ❌

### Error: "uv is not installed or not in PATH"

**Solution:** Install uv before using this action:

```yaml
steps:
  - name: Install uv
    uses: astral-sh/setup-uv@v7
    with:
      python-version: '3.11'
```

### Error: "No compatible version found"

This happens when no version of the package is compatible with your Python version.

**Solutions:**
- Check the package's Python version requirements on PyPI
- Try a different Python version
- Try an older version of the package that supports your Python version

### Using Custom or Private PyPI Indexes

Use the `uv-args` input to specify custom indexes:

```yaml
steps:
  - name: Install from custom index
    uses: durandtibo/uv-install-package-action@v0.1.1
    with:
      package-name: 'my-package'
      package-version: '1.0.0'
      python-version: '3.11'
      uv-args: '--index-url https://pypi.example.com/simple --extra-index-url https://pypi.org/simple'
```

For authenticated indexes, set environment variables:

```yaml
steps:
  - name: Install from authenticated index
    uses: durandtibo/uv-install-package-action@v0.1.1
    with:
      package-name: 'my-package'
      package-version: '1.0.0'
      python-version: '3.11'
      uv-args: '--index-url https://${{ secrets.PYPI_USER }}:${{ secrets.PYPI_PASSWORD }}@pypi.example.com/simple'
```

### Network or PyPI Connection Issues

If PyPI queries fail due to network issues:
- Check GitHub Actions service status
- Verify network connectivity in your workflow
- Try adding retry logic around the action

### Installation Fails After Finding Version

If the action finds a version but installation fails:
- Check the package's dependencies for compatibility issues
- Review the full error output
- Try installing with additional uv arguments (e.g., `--no-deps` to skip dependencies)

## Suggestions and Communication

Everyone is welcome to contribute to the community.
If you have any questions or suggestions, you can
submit [Github Issues](https://github.com/durandtibo/uv-install-package-action/issues).
We will reply to you as soon as possible. Thank you very much.

## License

`uv-install-package-action` is licensed under BSD 3-Clause "New" or "Revised" license available
in [LICENSE](LICENSE) file.
