# noqa: INP001
r"""Script to create or update the package versions."""

from __future__ import annotations

import logging
from pathlib import Path

from feu.utils.io import save_json
from feu.version import (
    get_latest_major_versions,
    get_latest_minor_versions,
)

logger = logging.getLogger(__name__)


def get_package_versions() -> dict[str, list[str]]:
    r"""Get the versions for each package.

    Returns:
        A dictionary with the versions for each package.
    """
    return {
        "click": list(get_latest_minor_versions("click", lower="8.1")),
        "jax": list(get_latest_minor_versions("jax", lower="0.4")),
        "matplotlib": list(get_latest_minor_versions("matplotlib", lower="3.6")),
        "numpy": list(get_latest_minor_versions("numpy", lower="1.22")),
        "pandas": list(get_latest_minor_versions("pandas", lower="1.2")),
        "pyarrow": list(get_latest_major_versions("pyarrow", lower="5.0")),
        "requests": list(get_latest_minor_versions("requests", lower="2.25")),
        "scikit-learn": list(get_latest_minor_versions("scikit-learn", lower="1.0")),
        "scipy": list(get_latest_minor_versions("scipy", lower="1.10")),
        "torch": list(get_latest_minor_versions("torch", lower="2.0")),
        "xarray": list(get_latest_minor_versions("xarray", lower="2023.1")),
    }


def main() -> None:
    r"""Generate the package versions and save them in a JSON file."""
    versions = get_package_versions()
    logger.info(f"{versions=}")
    path = Path(__file__).parent.parent.joinpath("dev/config").joinpath("package_versions.json")
    logger.info(f"Saving package versions to {path}")
    save_json(versions, path, exist_ok=True)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    main()
