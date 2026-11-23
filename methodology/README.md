# Methodology

How work is done in tx-mdm. The approach is Spec-Driven Development (SDD), adapted to a
small, one-owner Python + TypeScript repo:

- the spec is the control surface
- each change goes through a fixed lifecycle
- every "done" claim carries evidence someone can check

| File | What it is |
|---|---|
| [`constitution.md`](constitution.md) | The invariants that hold for every change. Wins over any other document. |
| [`sdd-lifecycle.md`](sdd-lifecycle.md) | The six phases a change goes through, and the `changes/` -> `specs/` flow. |
| [`operating-procedures.md`](operating-procedures.md) | The agent contract: task brief, report format, one example first, stop conditions, verification ladder, hill climbing. |
| [`decisions.md`](decisions.md) | Dated decision log: what was decided, why, and what it supersedes. |
| [`review-guide.md`](review-guide.md) | A ten-point checklist for reviewing Python (FastAPI) and TypeScript (React / UI SDK) changes. |

Related folders:

- [`../specs/`](../specs/) - the current state of what the system does (CDI, MDM, agent interface).
- [`../changes/`](../changes/) - one folder per change proposal, plus templates. Archived
  changes go to `changes/archive/`.
- [`../internal-notes/`](../internal-notes/) - working notes for the agent: gotchas, API
  facts, next steps.

The guiding rule: **if it is not in a file in this repo, it did not happen.** Chat is not a
record.
