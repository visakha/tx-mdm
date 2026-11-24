"""--local: start the tx-mdm backend on this machine (mock path only needs no IDMC login).

Runs the backend's own venv python as a subprocess - nothing is imported from the backend.
"""

import os
import subprocess
import sys
import tempfile
import time
from collections.abc import Generator
from contextlib import contextmanager
from pathlib import Path

import httpx

DEFAULT_BACKEND = Path(__file__).resolve().parents[3] / "backend"


def backend_python(backend: Path) -> Path:
    venv = backend / ".venv"
    found = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    return found if found.is_file() else Path(sys.executable)


@contextmanager
def local_backend(backend: Path = DEFAULT_BACKEND, port: int = 8765) -> Generator[str]:
    url = f"http://127.0.0.1:{port}"
    env = {
        **os.environ,
        "IDMC_USERNAME": "local-mock-only",
        "IDMC_PASSWORD": "local-mock-only",  # dummy: the mock path never logs in
        "TXMDM_TEST_RUNS_DIR": tempfile.mkdtemp(prefix="txmdm-runs-"),
    }
    cmd = [str(backend_python(backend)), "-m", "uvicorn", "app.main:app", "--port", str(port)]
    proc = subprocess.Popen(
        cmd, cwd=backend, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    try:
        for _ in range(120):
            if proc.poll() is not None:
                raise RuntimeError(f"backend exited early ({proc.returncode}): {' '.join(cmd)}")
            try:
                if httpx.get(f"{url}/api/health", timeout=1, trust_env=False).status_code == 200:
                    break
            except httpx.HTTPError:
                time.sleep(0.5)
        else:
            raise RuntimeError(f"backend did not answer on {url} within 60 s")
        yield url
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
