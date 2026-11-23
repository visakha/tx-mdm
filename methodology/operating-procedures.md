# Agent operating procedures

How any agent (Muse or another) works on tx-mdm. The owner, Vamsi, reasons about agent work
from the agent's **report**, so the report has to be enough on its own.

## 1. The task brief - every task carries all of these

A task brief that is missing any of these fields is malformed. Stop and ask.

| Field | Contents |
|---|---|
| `task_id` | `TASK-YYYY-MM-DD-NNN` |
| `change` | `changes/NNN-<slug>/`, or the reason there is none (e.g. a pure investigation) |
| `phase` | discover / design / tasks / implement / converge / archive (exactly one) |
| `title` | Verb plus noun, naming the module, e.g. "Add egress jobType capture to `app/mdm/resolver.py`" |
| `contracts_touched` | none, or the named contracts: API routes/schemas, RunView, routes, agent actions |
| `inputs` / `outputs` | Exact paths the task may read and change |
| `done_test` | Exact commands with the expected result |
| `stop_conditions` | The section 5 conditions that apply (at least S1, S3, S4) |
| `example_first` | What the ONE example is (section 3) |

## 2. The report - the only thing Vamsi has to read

The report is filed in the change's `tasks.md` (or `internal-notes/` for an investigation) and
returned as the agent's reply. It has these sections, in this order. Write "None" rather than
dropping a section.

1. **Task** - id, title, one line on what was asked.
2. **Result** - DONE / STOPPED / PARTIAL.
3. **What changed** - files with `+added/-removed` line counts, one sentence each.
4. **Checks run** - every command, verbatim, with its pass/fail counts. A check that was not
   run is written "NOT RUN" with the reason.
5. **What I did NOT do** - what was not touched, follow-ups not started, live calls not made.
6. **Open questions** - numbered, each answerable in one reply, each with a proposed answer.
7. **How to verify in 5 minutes** - copy-paste commands with expected output.
8. **Stop conditions triggered** - None, or the S-number and what was written instead.
9. **Convergence** - the verdict, or "Not run" and why.
10. **Intent-loss attribution** - for each gap: its loss point (`sdd-lifecycle.md`) and the
    workflow fix.

## 3. One example first, then the set - HARD RULE

When a task produces many similar things (endpoints, panels, tests, specs), do this:

1. Build **one**.
2. Show it.
3. Wait for Vamsi's explicit go, in words.
4. Then build the rest in exactly that shape and scope.

A correction to the example applies to the whole set.

## 4. File ownership and handoffs

- Only one agent edits a file at a time. Before starting, claim the files in the task brief.
- If a file is already claimed, stop and report it as blocked. Never overwrite another agent's
  work.
- A handoff note says: what is done, what is next, which files changed, and which checks pass.

## 5. Stop conditions - stop and report instead of pushing on

| # | Condition | Write instead of proceeding |
|---|---|---|
| S1 | A contract or a constitution principle would change | The proposed change as a quoted diff, under Open questions |
| S2 | A check fails and you cannot explain why in one paragraph | The command, its output, and what was tried. Never weaken the check. |
| S3 | The spec has two readings, or does not cover the case | Both readings, and which one you would pick and why |
| S4 | A new dependency (pip or npm) is wanted | Its name, why the stdlib or existing deps cannot do it, and a one-line justification. Add it only after the go. |
| S5 | A readability rule cannot be met | The rule, the code, and the redesign you propose |
| S6 | A live IDMC response contradicts `api-facts.md` or a spec | The redacted response, the documented expectation, the diff |
| S7 | A live call to the org, or starting a job, has not been explicitly authorised | Nothing runs. Ask. |
| S8 | The work will not fit one session | The remainder, split into named follow-up tasks. Result: PARTIAL. |
| S9 | Two instructions conflict | Both, quoted, and which one was followed for any work already done |
| S10 | A secret or credential would end up in a file, log or commit | Stop. Remove it. Report it without the value. |

## 6. Hill climbing - for the parts a spec cannot predict

A climb needs four things in the brief. Without all four it is malformed:

1. **The objective** - a measurable gate. Examples: "resolver maps 100% of the org's
   `MDM_JOB_DEFINITION`s with 0 wrong mappings, checked against a list Vamsi confirmed", or
   "0 HTTP 429s across a 30-minute poll of 5 runs".
2. **The knobs**, with bounds (e.g. name-normalisation rule A/B/C; poll interval 3-15 s, in 2 s
   steps).
3. **The baseline** - the last measured numbers, and the command that produced them.
4. **The change proposal** that frames the climb.

The loop:

1. Start from the baseline.
2. Make ONE change (one knob, one step).
3. Measure.
4. **Keep** the change only if the objective improved and nothing else regressed. Otherwise
   **revert exactly**.
5. Log the attempt: number, the change, the before -> after numbers, kept or reverted, one line
   on why.
6. Repeat from the new baseline.

Moving two knobs at once voids the attempt.

**Stop and escalate,** with the attempt log, when any of these happens:

- the gate is met
- 5 attempts in a row show no improvement
- 20 attempts in total
- a plateau: three different knobs each move the number by less than the noise

On a plateau, propose a change of *shape*, not of size. Never start a new climb on your own.

Climbs that touch the real org also fall under S7, and each live call needs authorisation.

## 7. Verification ladder - what "done" means

Do the levels in order. Write a level that does not apply as "N/A - reason".

| Level | Check |
|---|---|
| L0 Types | `mypy app` (strict) clean; `npm run typecheck` clean |
| L1 Format/lint | `ruff format --check . && ruff check .`; `npm run lint` |
| L2 Unit/route tests | `pytest -q`; `npm test` |
| L3 Build | `npm run build`; backend imports and `create_app().openapi()` builds |
| L4 Offline end-to-end | backend + `dev/fake_idmc.py` + UI: list -> run -> results, when the change touches that flow |
| L5 Live | against the real org, only with authorisation (S7). Record the result in `internal-notes/api-facts.md` |
| L6 Owner's 5-minute check | Vamsi runs the report's "How to verify" commands |

## 8. Anti-patterns

- **Silently "improving" a contract.** That is S1: propose it, don't do it.
- **Reporting tests that were never run.** Every claim carries its command.
- **Calling a mocked fact verified.** Use the DOC / CODE / LIVE labels.
- **Building the whole set before the example.** See section 3.
- **Retrying a failed job "to be helpful".** This violates Principle IV.
- **Copying content from other private projects into this public repo.** This violates
  Principle X.
