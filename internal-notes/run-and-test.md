# Run and test - exact commands

## Backend

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -e '.[dev]'
.venv/bin/pytest -q            # 20 tests, no network
.venv/bin/ruff check . && .venv/bin/ruff format --check .
.venv/bin/mypy app             # strict
```

## Frontend

```bash
cd frontend
npm install
npm run typecheck && npm test && npm run lint && npm run build
```

## Run the whole thing offline (fake IDMC)

```bash
# terminal 1 - fake IDMC
cd backend && .venv/bin/uvicorn dev.fake_idmc:app --port 8900
# terminal 2 - backend pointed at the fake
cd backend && IDMC_USERNAME=demo IDMC_PASSWORD=demo \
  IDMC_LOGIN_URL=http://127.0.0.1:8900 IDMC_MDM_URL=http://127.0.0.1:8900 \
  IDMC_PLATFORM_URL=http://127.0.0.1:8900/saas \
  .venv/bin/uvicorn app.main:app --port 8000
# terminal 3 - UI
cd frontend && npm run dev     # open http://localhost:5173 (localhost, not 127.0.0.1)
```

You do not need to unset proxy env vars. The backend ignores them unless `HTTP_TRUST_ENV=true`
(see gotchas section 1).

## The agent-facing surfaces

- OpenAPI: `http://127.0.0.1:8000/openapi.json` (each operation has an `operationId`, for
  example `mdm_start_run`) and `/docs`.
- In the browser console: `txmdm.describe()` lists the declared actions.

## Before every push (the repo is public)

```bash
# 1. No env files or credential images tracked
git ls-files | grep -Ei '(^|/)\.env$|\.pem$|\.key$|photo.*\.jpe?g$' && echo "STOP"
# 2. No password/session values in the staged diff (look at every hit by eye)
git diff --cached | grep -niE 'password|passwd|sessionid|icsessionid|secret|token' | grep -v -iE 'placeholder|SecretStr|your-|<.*>|\{\{' | head
# 3. After the push: verify on origin, then build from a clean clone
git ls-remote origin main
```

## Handshake after a pull + restart

`GET /api/about` returns `{"version": "x.y.z", "highlights": [three plain-English bullets]}`.
Both live in `backend/app/version.py`. After `git pull` + restart, call it and check the
version is the one you expect; the UI title bar shows it too (`about-version`), and agents can
call `txmdm.about()`.

## B360 entities file (0.9.7)

- `backend/b360_entities.toml` holds the left-pane entity list. Read ONCE at startup
  (`app/b360data/scope.py`, stdlib tomllib -> Pydantic `FocusConfig`). Edit, then restart uvicorn.
- `B360_ENTITIES_FILE=/path/other.toml` points elsewhere (tests use tmp files).
- Bad file (not TOML, missing `name`, unknown key, bad characters, duplicate) = `FocusConfigError`
  at startup. Check: `GET /api/b360/entities` -> `focus` (each entry with `found`) and `focus_file`.
