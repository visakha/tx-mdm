# Review guide - Python (FastAPI) and TypeScript (React / UI SDK)

This guide is for the owner, who reads Java fluently, and for the converge pass. The aim is to
review one changed file in about five minutes.

## The ten questions

1. **Can I read it top to bottom without stopping?** If a line stopped you, note which one. That
   line is the defect.
   Any non-ASCII character (emoji, icon, fancy dash, arrow, box glyph) is also a defect:
   ASCII only in code, logs, terminal output and docs (Windows terminals).
2. **Does every function do one job, in about 40 lines or fewer?** Name the job in one sentence.
3. **Are the types explicit?**
   - Python: parameters and return types are annotated, and data crossing a boundary is a
     Pydantic model or a dataclass, not a loose `dict`.
   - TS: no `any`, no non-null `!` without a reason, and state is a discriminated union handled
     by a `switch`.
4. **Is every Informatica URL a named constant** in `endpoints.py`? A string-built URL in a
   client method is a defect.
5. **Is the wiring explicit?** Dependencies come in through `Depends(...)` or constructor
   arguments. Nothing is created inside a route handler, and there are no module-level
   singletons other than the `lru_cache` providers in `dependencies.py`.
6. **Are CDI and MDM still separate?** No import from `app/cdi` into `app/mdm` or back (the
   same goes for `src/cdi` and `src/mdm`). Shared code lives in `common/` / `shared/` and is
   about the shell or the run shape.
7. **What happens on failure?** For each IDMC call, check that a 401 re-logs in once, a 429 is
   surfaced as-is, other 4xx/5xx become `IdmcError` (502), and the person sees a readable
   message. Check also that no retry of a job was added.
8. **Can a secret leak?** The password stays a `SecretStr`; no session id appears in a log,
   error text or response; no `.env` is staged.
9. **Is there one test per rule, named for what it proves?**
   - Python: pytest with respx fixtures, no network.
   - TS: vitest for pure logic (routes, run status).
   - No test for trivial getters.
10. **Did any contract change?** API paths/schemas/operationIds, the `RunView` fields, routes,
    `window.txmdm` actions, `data-testid`s. If one did, check it is in the change's spec delta
    and in `specs/`.

## Java analogies (for reading quickly)

| You see | Read it as |
|---|---|
| `class X(BaseModel)` (Pydantic) | A Java record with validation; the `Field(description=...)` text ends up in the OpenAPI |
| `Depends(get_cdi_service)` | Constructor injection; `dependencies.py` is the `@Configuration` class |
| `@lru_cache def get_x()` | A singleton `@Bean` |
| `SecretStr` | A `char[]` that prints as `**********` |
| `respx` fixture | A hand-written fake HTTP server, like WireMock |
| TS `type Route = {screen:"jobs"} \| {screen:"job", jobId}` | A sealed interface with record subtypes; `switch (route.screen)` is a switch expression that the compiler checks for exhaustiveness |
| `useState` / `useEffect` | A field, plus a lifecycle callback that re-runs when its listed inputs change |
| `async`/`await` + `Promise<T>` (TS only) | `CompletableFuture<T>` with `.thenApply`, written straight-line |

## When to stop reading and ask

Stop when a file needs more than five minutes, or when you cannot say what a function is for.
Return it with the line number and the question. The fix is usually a smaller function or a
better name, not a comment.
