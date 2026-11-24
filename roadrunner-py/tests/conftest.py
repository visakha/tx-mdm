"""Fixtures: backend URL (TXMDM_BASE_URL, or TXMDM_LOCAL=1 starts one), path, work folder."""

import os
from collections.abc import Generator
from pathlib import Path

import pytest

from roadrunner.api import RunPath, TestApi
from roadrunner.handshake import Pauses, auto_from_env
from roadrunner.local import local_backend


@pytest.fixture(scope="session")
def base_url() -> Generator[str]:
    if os.environ.get("TXMDM_LOCAL", "") == "1":
        with local_backend() as url:
            yield url
    else:
        yield os.environ.get("TXMDM_BASE_URL", "http://127.0.0.1:8000")


@pytest.fixture(scope="session")
def api(base_url: str) -> TestApi:
    return TestApi(base_url, RunPath(os.environ.get("TXMDM_PATH", "mock")))


@pytest.fixture(scope="session")
def work(tmp_path_factory: pytest.TempPathFactory) -> Path:
    given = os.environ.get("TXMDM_WORK")
    return Path(given) if given else tmp_path_factory.mktemp("roadrunner")


@pytest.fixture
def pauses() -> Pauses:
    return Pauses(auto=auto_from_env())
