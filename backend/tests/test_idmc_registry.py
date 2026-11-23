"""0.9.14: /openapi-idmc.json comes from ONE registry (app/common/idmc_registry.py), and every
outbound IDMC call in the code goes through it."""

import ast
from pathlib import Path

from fastapi.testclient import TestClient

from app.b360data import endpoints as b360_ep
from app.cdi import endpoints as cdi_ep
from app.common import idmc_registry as registry
from app.common import idmc_session
from app.common.idmc_openapi import build
from app.common.idmc_registry import IDMC_CALLS, LOGIN, SOURCE_SYSTEMS, DocStatus
from app.design import endpoints as design_ep
from app.main import create_app
from app.mdm import endpoints as mdm_ep

APP = Path(__file__).resolve().parents[1] / "app"
SENDER = "common/idmc_session.py"


def _path_constants() -> dict[str, str]:
    out: dict[str, str] = {}
    for module in (b360_ep, cdi_ep, mdm_ep, design_ep):
        for name, value in vars(module).items():
            if name.isupper() and isinstance(value, str) and value.startswith("/"):
                out[f"{module.__name__}.{name}"] = value
    out["idmc_session.V3_LOGIN_PATH"] = idmc_session.V3_LOGIN_PATH
    return out


def test_every_endpoint_path_constant_is_in_the_registry() -> None:
    registered = {spec.path for spec in IDMC_CALLS}
    missing = {k: v for k, v in _path_constants().items() if v not in registered}
    assert missing == {}, f"IDMC paths in code but not in idmc_registry.py: {missing}"


def test_every_outbound_call_names_a_registry_row() -> None:
    """Static scan: each .request( / .request_bytes( call on an IdmcHttp passes a registry spec
    (idmc.<NAME> or a parameter named spec) as its first argument - never a method string."""
    names = {name for name, value in vars(registry).items() if value in IDMC_CALLS}
    bad: list[str] = []
    for path in APP.rglob("*.py"):
        if path.relative_to(APP).as_posix() == SENDER:
            continue  # IdmcHttp._send: the one place that hands spec.method to httpx
        tree = ast.parse(path.read_text(encoding="ascii"))
        for node in ast.walk(tree):
            if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)):
                continue
            if node.func.attr not in ("request", "request_bytes"):
                continue
            owner = node.func.value
            if not (isinstance(owner, ast.Attribute) and owner.attr == "_http"):
                continue
            first = node.args[0] if node.args else None
            ok = (
                isinstance(first, ast.Attribute)
                and isinstance(first.value, ast.Name)
                and first.value.id == "idmc"
                and first.attr in names
            ) or (isinstance(first, ast.Name) and first.id == "spec")
            if not ok:
                bad.append(f"{path.relative_to(APP)}:{node.lineno}")
    assert bad == [], f"IDMC calls not naming a registry row: {bad}"


def test_spec_has_only_idmc_paths() -> None:
    spec = build()
    paths = spec["paths"]
    assert isinstance(paths, dict) and len(paths) >= 20
    assert not [p for p in paths if p.startswith("/api/")], "our /api routes must not appear"
    ops = [op for item in paths.values() for k, op in item.items() if k != "servers"]
    assert len(ops) == len(IDMC_CALLS)
    login = paths[LOGIN.path]["post"]
    assert login["security"] == [] and "LoginRequest" in str(login["requestBody"])
    src = paths[SOURCE_SYSTEMS.path]["get"]
    assert src["x-doc-status"] == "UNVERIFIED-DOC"
    assert SOURCE_SYSTEMS.status == DocStatus.UNVERIFIED_DOC
    assert "/saas/api/v2/job" in paths and "/saas/public/core/v3/objects" in paths
    merge = paths["/business-entity/public/api/v1/entity-group/{guid}"]["post"]
    assert merge["security"] == [{"IDS-SESSION-ID": []}]
    assert merge["requestBody"]["content"]["application/json"]["schema"]["type"] == "array"
    assert paths["/saas/api/v2/job"]["post"]["security"] == [{"icSessionId": []}]
    assert all(ord(ch) < 128 for ch in str(spec))


def test_routes_serve_the_third_spec_separately() -> None:
    client = TestClient(create_app())
    idmc = client.get("/openapi-idmc.json").json()
    assert idmc["info"]["title"] == "IDMC calls made by tx-mdm"
    assert client.get("/docs-idmc").status_code == 200
    ours = client.get("/openapi.json").json()
    assert "/saas/api/v2/job" not in ours["paths"]
    assert not [p for p in idmc["paths"] if p.startswith("/api/")]
