"""Copy IDMC curl (0.9.12.4, Vamsi 02:48-02:50 CST): "the true curl that I should be able to run
so that it will hit the IDMC APIs and not the APIs that we are writing here."

While one backend request runs, IdmcHttp records every IDMC call it sends (method, full URL with
query, the NAMES of the session headers, JSON body) into a list held in a ContextVar. A middleware
gives that list an id (response header X-Idmc-Echo-Id) and keeps the last ECHO_KEEP in memory.
GET /api/idmc/echo/{id} turns it into runnable PowerShell and bash scripts: step 1 logs in
(password from $env:IDMC_PASSWORD / $IDMC_PASSWORD), step 2.. the exact IDMC calls with the
session id variable. Never stored: the session id value, the password. The login POST itself is
not recorded (it does not go through IdmcHttp._send).
"""

import json
import threading
from collections import OrderedDict
from contextvars import ContextVar
from typing import Any
from uuid import uuid4

from pydantic import BaseModel, Field

from app.common.idmc_registry import LOGIN, IdmcCallSpec, SessionHeader

ECHO_KEEP = 200
MAX_CALLS_IN_SCRIPT = 25
LOGIN_PATH = LOGIN.path
SESSION_VAR_PS = "$sid"
SESSION_VAR_SH = "$SID"


class IdmcCall(BaseModel):
    call_id: str = Field(description="Registry id (app/common/idmc_registry.py, /docs-idmc).")
    method: str
    url: str = Field(description="Full IDMC URL including the query string.")
    session_headers: list[SessionHeader]
    accept: str
    body: str | None = Field(default=None, description="JSON body exactly as sent, or null.")
    writes: bool = Field(description="True for POST / PUT / PATCH / DELETE.")


class LoginEcho(BaseModel):
    url: str
    username: str
    password_env: str = "IDMC_PASSWORD"


class IdmcEcho(BaseModel):
    echo_id: str
    api_method: str = Field(description="The tx-mdm call that caused these IDMC calls.")
    api_path: str
    calls: list[IdmcCall]
    calls_left_out: int = Field(default=0, description="Calls beyond the script cap.")
    login: LoginEcho | None
    powershell: str = Field(description="Runnable on Windows PowerShell (curl.exe).")
    bash: str = Field(description="Runnable in bash (curl, python3 for the session id).")
    readme: str
    writes: bool = Field(description="True if any call writes. Copying never runs anything.")


class _Recorded(BaseModel):
    calls: list[IdmcCall] = Field(default_factory=list)
    login: LoginEcho | None = None


_CURRENT: ContextVar[_Recorded | None] = ContextVar("idmc_echo_current", default=None)
_STORE: "OrderedDict[str, tuple[str, str, _Recorded]]" = OrderedDict()
_LOCK = threading.Lock()


def begin() -> _Recorded:
    recorded = _Recorded()
    _CURRENT.set(recorded)
    return recorded


def record(
    spec: IdmcCallSpec,
    url: str,
    accept: str,
    body: Any,
    login_url: str,
    username: str,
) -> None:
    """Called by IdmcHttp._send. Header VALUES are never passed in."""
    recorded = _CURRENT.get()
    if recorded is None:
        return
    headers = [] if spec.auth is None else [spec.auth]
    recorded.calls.append(
        IdmcCall(
            call_id=spec.id,
            method=spec.method.value,
            url=url,
            session_headers=headers,
            accept=accept,
            body=None if body is None else json.dumps(body, indent=2, ensure_ascii=True),
            writes=spec.writes,
        )
    )
    if recorded.login is None:
        recorded.login = LoginEcho(url=login_url.rstrip("/") + LOGIN_PATH, username=username)


def finish(recorded: _Recorded, api_method: str, api_path: str) -> str | None:
    """Keep the recorded calls; return their echo id (None when no IDMC call was made)."""
    if not recorded.calls:
        return None
    echo_id = uuid4().hex
    with _LOCK:
        _STORE[echo_id] = (api_method, api_path, recorded)
        while len(_STORE) > ECHO_KEEP:
            _STORE.popitem(last=False)
    return echo_id


def get(echo_id: str) -> IdmcEcho | None:
    with _LOCK:
        kept = _STORE.get(echo_id)
    if kept is None:
        return None
    api_method, api_path, recorded = kept
    calls = recorded.calls[:MAX_CALLS_IN_SCRIPT]
    return IdmcEcho(
        echo_id=echo_id,
        api_method=api_method,
        api_path=api_path,
        calls=calls,
        calls_left_out=max(0, len(recorded.calls) - len(calls)),
        login=recorded.login,
        powershell=powershell(recorded.login, calls),
        bash=bash(recorded.login, calls),
        readme=(
            "Runs against IDMC directly, not tx-mdm. Set the password first - PowerShell: "
            '$env:IDMC_PASSWORD = "<your password>"   bash: export IDMC_PASSWORD=\'<your '
            "password>'. Step 1 logs in and keeps the session id in a variable; the next steps "
            "are the exact IDMC calls tx-mdm made for this screen. Write calls (POST / PATCH) "
            "change data in IDMC when YOU run them; copying runs nothing."
        ),
        writes=any(c.writes for c in calls),
    )


# ---- script builders (ASCII only) ----------------------------------------------------------


def _ps_quote(text: str) -> str:
    """PowerShell single-quoted string: '' escapes '."""
    return "'" + text.replace("'", "''") + "'"


def _sh_quote(text: str) -> str:
    """bash single-quoted string: '\\'' escapes '."""
    return "'" + text.replace("'", "'\\''") + "'"


def powershell(login: LoginEcho | None, calls: list[IdmcCall]) -> str:
    lines = [
        "# tx-mdm: exact IDMC calls (runs against IDMC, not tx-mdm). PowerShell + curl.exe.",
        '# First:  $env:IDMC_PASSWORD = "<your password>"',
    ]
    if login is not None:
        lines += [
            "# Step 1: log in, keep the session id",
            "$login = Invoke-RestMethod -Method Post -Uri "
            + _ps_quote(login.url)
            + ' -ContentType "application/json" -Body (@{ username = '
            + _ps_quote(login.username)
            + "; password = $env:IDMC_PASSWORD } | ConvertTo-Json)",
            f"{SESSION_VAR_PS} = $login.userInfo.sessionId",
        ]
    for n, call in enumerate(calls, start=2):
        lines.append(f"# Step {n}: {call.method}{'  (WRITES to IDMC)' if call.writes else ''}")
        args = [f"curl.exe -s -X {call.method} {_ps_quote(call.url)}"]
        args += [f'-H "{h.value}: {SESSION_VAR_PS}"' for h in call.session_headers]
        args.append(f'-H "Accept: {call.accept}"')
        if call.body is not None:
            # Body via a file: Windows PowerShell 5 strips quotes from JSON passed to curl.exe.
            lines += ["$body = @'", call.body, "'@", "Set-Content -Path body.json -Value $body"]
            args += ['-H "Content-Type: application/json"', '--data-binary "@body.json"']
        lines.append(" ".join(args))
    return "\n".join(lines) + "\n"


def bash(login: LoginEcho | None, calls: list[IdmcCall]) -> str:
    lines = [
        "# tx-mdm: exact IDMC calls (runs against IDMC, not tx-mdm). bash + curl + python3.",
        "# First:  export IDMC_PASSWORD='<your password>'",
    ]
    if login is not None:
        lines += [
            "# Step 1: log in, keep the session id",
            'SID=$(python3 -c \'import json,os,sys; print(json.dumps({"username": sys.argv[1], '
            '"password": os.environ["IDMC_PASSWORD"]}))\' '
            + _sh_quote(login.username)
            + " | curl -s -X POST "
            + _sh_quote(login.url)
            + ' -H "Content-Type: application/json" -H "Accept: application/json" '
            "--data-binary @- | python3 -c 'import json,sys; "
            'print(json.load(sys.stdin)["userInfo"]["sessionId"])\')',
        ]
    for n, call in enumerate(calls, start=2):
        lines.append(f"# Step {n}: {call.method}{'  (WRITES to IDMC)' if call.writes else ''}")
        args = [f"curl -s -X {call.method} {_sh_quote(call.url)}"]
        args += [f'-H "{h.value}: {SESSION_VAR_SH}"' for h in call.session_headers]
        args.append(f'-H "Accept: {call.accept}"')
        if call.body is not None:
            args += ['-H "Content-Type: application/json"', "--data-binary @- <<'JSON'"]
            lines.append(" ".join(args))
            lines += [call.body, "JSON"]
        else:
            lines.append(" ".join(args))
    return "\n".join(lines) + "\n"
