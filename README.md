# Python Package GitHub Action

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

GitHub action to find valid package versions based on python version.

## What's new

Please refer to
the [release page](https://github.com/durandtibo/uv-install-package-action/releases) for
the latest release notes.

### Basic usage

```yaml
  - name: Install valid package version
    uses: durandtibo/uv-install-package-action@v0.1.0
    with:
      package-name: 'numpy'
      package-version: 2.0.2
      python-version: 3.11
```

### Inputs

| name              | description                             | default value |
|-------------------|-----------------------------------------|---------------|
| `package-name`    | The package name e.g. `numpy`           | none          |
| `package-version` | The target package version e.g. `2.0.2` | none          |
| `python-version`  | The python version e.g. `3.11`          | none          |
| `uv-args`         | Optional uv arguments                   | `''`          |

### Outputs

| name                    | description                                                       |
|-------------------------|-------------------------------------------------------------------|
| `closest-valid-version` | The closest valid package version given the input package version |                                                    |

## Suggestions and Communication

Everyone is welcome to contribute to the community.
If you have any questions or suggestions, you can
submit [Github Issues](https://github.com/durandtibo/uv-install-package-action/issues).
We will reply to you as soon as possible. Thank you very much.

## License

`uv-install-package-action` is licensed under BSD 3-Clause "New" or "Revised" license available
in [LICENSE](LICENSE) file.
