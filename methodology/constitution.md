# tx-mdm - Constitution

**Version:** 1.0.0 (ratified 2026-11-22)

This file holds the invariants that are true of **every** change. A feature spec holds only
what is specific to that feature. If this file and a spec disagree, this file wins, and the
spec is amended to match.

Standing context is grown, not installed. A rule earns its place here by recurring. A decision
that is true of one feature belongs in that feature's spec, under Out of scope or Assumptions.

## Principles

### I. The backend owns every Informatica call (NON-NEGOTIABLE)

The browser talks only to the FastAPI backend, on its own origin. Credentials live in the
backend's environment (`.env`, git-ignored) and nowhere else: no password or session id in the
browser, a log, an error message, a test fixture or a commit.

### II. CDI and MDM are separate concerns

Each has its own module, router, session, host, list, run registry, frontend panel and API
module. They share only the app shell and the `RunView` shape. A change that makes one import
the other is a design decision, not a refactor. Record it in `decisions.md`.

### III. Pickers come from metadata APIs

Job and task lists come from IDMC's own metadata calls. They are never built from past runs or
a hand-kept list. If metadata lacks something (e.g. the MDM `jobDefinitionId`), fill the gap
behind a named, pluggable, clearly-marked component. Do not paper over it.

### IV. A run is started once (NON-NEGOTIABLE)

- One active run per job.
- A failed run is recorded and **never** retried automatically.
- HTTP 429 from Informatica is a hard stop: surface it, do not retry.
- The only automatic resend is a single re-login after a 401. The request never reached the
  job, so the resend is not a job retry.
- An agent may start a run only after a person confirms it.

### V. The spec is the source of truth

- A behaviour change starts in `changes/<slug>/` and lands in `specs/` when it is archived.
- When code and spec disagree, fix the spec first, then bring the code in line. Never update
  the spec to describe whatever the code happens to do.
- Code without a spec line behind it is a defect to report, not a feature.

### VI. Verified means verified somewhere you can name

- Every Informatica fact is labelled DOC, CODE or LIVE (`internal-notes/api-facts.md`).
- Nothing is called LIVE until it has run against the real org, with the date recorded.
- A test against a mock proves the code. It does not prove the API.

### VII. Readable by a Java developer on first sight

- **Python:** typed Pydantic models, explicit client/service classes, named endpoint
  constants, FastAPI `Depends` wiring, `ruff` + `mypy --strict` clean, no metaclass or
  decorator magic beyond FastAPI/Pydantic's own.
- **TypeScript:** `strict` on, no `any`, discriminated unions plus `switch` for state, small
  components and hooks.
- Comments explain **why**, not what.
- **ASCII only** in code, logs, terminal output and docs - no emoji, icons or special Unicode
  (Windows terminals garble them). Enforced by `backend/tests/test_ascii_only.py`.
- No clever abstractions; mid-level-engineer simplicity.

### VIII. Necessary-only

No code, test, comment, document or dependency that does not serve the feature, the test or the
next reader. Tests are written where they add value: rules (run registry, status mapping,
routes, the proxy policy) and API contracts, not getters. Hand-written fakes are fine; there is
no mock framework beyond `respx` for HTTP.

### IX. Agent-friendly by construction

- Every screen has a stable URL.
- Every key control has a stable `data-testid` and an aria label.
- The declared agent actions (`window.txmdm`) and the OpenAPI schema (summaries, descriptions,
  `operationId`s) are part of the public contract: changing them is a spec change.

### X. Public repository hygiene (NON-NEGOTIABLE)

This repo is public:

- Commit no passwords, session ids, `.env` files, or images that show credentials.
- Run the secret scan before every push.
- The IDMC username and hostnames are allowed.
- Content from other private projects does not come in here.

## Mandatory questions - every change proposal answers these

1. **Who is this for?** Name the actor: Vamsi in the UI, an agent through `window.txmdm`, an
   agent through the OpenAPI, or the backend itself.
2. **What happens when it fails, and what does the person see?** Name the outcome for each
   failure: an IDMC 4xx/5xx, a 429, an expired session, an unknown job, an unresolved MDM id,
   a backend restart mid-run.
3. **What is explicitly out of scope?**
4. **What is the evidence that it worked?** Name the test, command or live check, with its
   expected output, before implementation starts.
5. **Does it touch a contract or a principle?** Contracts are the API routes and schemas, the
   agent actions, the routes and the RunView shape. If yes, who decided?

## Governance

- **Amendment:** a principle added, removed or reversed is MAJOR; clarified is MINOR; wording
  only is PATCH. Update the version line and add a `decisions.md` entry in the same change.
- When in doubt, put a rule in the feature spec, not here. Promoting a rule too early is harder
  to undo than promoting it late.
