from __future__ import annotations

import pytest
from feu.imports import is_package_available
from feu.testing import (
    numpy_available,
    sklearn_available,
    torch_available,
)

pydantic_available: pytest.MarkDecorator = pytest.mark.skipif(
    not is_package_available("pydantic"), reason="Requires pydantic"
)


@pytest.fixture(autouse=True)
def _reset_cache() -> None:
    is_package_available.cache_clear()


@numpy_available
def test_numpy() -> None:
    import numpy as np  # local import because it is an optional dependency

    assert np.array_equal(np.ones((2, 3)) + np.ones((2, 3)), np.full((2, 3), 2.0))


@pydantic_available
def test_pydantic() -> None:
    from pydantic import BaseModel  # local import because it is an optional dependency

    class User(BaseModel):
        id: int
        name: str = "John Doe"

    user = User(id="123")
    assert user.id == 123
    assert user.name == "John Doe"


@sklearn_available
def test_sklearn() -> None:
    from sklearn.svm import SVC  # local import because it is an optional dependency

    model = SVC(C=0.1)
    assert model.C == 0.1


@torch_available
def test_torch() -> None:
    import torch  # local import because it is an optional dependency

    torch.testing.assert_close(torch.ones(2, 3) + torch.ones(2, 3), torch.full((2, 3), 2.0))
