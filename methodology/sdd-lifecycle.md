# The SDD lifecycle in tx-mdm

One feature = one change proposal = one folder `changes/NNN-<slug>/` with four artefacts:

| Artefact | Holds | Phase |
|---|---|---|
| `proposal.md` | **Why** (mandatory), what changes, what is out of scope, the answers to the constitution's mandatory questions | Discover |
| `specs/<area>.md` | The **what**: requirements `FR-nnn`, each with Given/When/Then scenarios and measurable outcomes `SC-nnn`. Deltas are marked ADDED / MODIFIED / REMOVED. | Discover |
| `design.md` | The **how**: decisions with rationale and the alternatives considered, files and modules affected, risks | Design |
| `tasks.md` | Acceptance tests **first** (each seen to fail for the right reason), then build tasks; every task has a done-check | Tasks |

Filing rule: if a decision must survive throwing the implementation away, it belongs in
`specs/`. Otherwise it belongs in `design.md`.

## The six phases

Run one phase per session, and commit at the end of each phase.

1. **Discover.** Interview Vamsi one question at a time, inside the proposal's scope, and
   draft the proposal and spec deltas. Exit: the review checklist below passes, and Vamsi says
   go.
2. **Design.** Draft `design.md`. Design may not change the spec's what. If the what has to
   change, go back to Discover; going back is normal, not rework to hide.
3. **Tasks.** Draft `tasks.md`. Then run the analyze check: every requirement has a task, and
   every task traces to a requirement.
4. **Implement.** Work through `tasks.md` in order, following `operating-procedures.md`.
5. **Converge.** A **separate** verification pass, by a different agent or a fresh session,
   checks the code against the spec, design and tasks. It appends any missing work to
   `tasks.md` and writes the verdict at the end of `tasks.md`. Maximum three rounds, then
   escalate to Vamsi. The implementer's own word is not a converge verdict.
6. **Archive.** Merge the spec deltas into `specs/` (the current state) and move the folder to
   `changes/archive/`. Only the specs sync; the proposal, design and tasks stay with the
   archived change as history.

## When a spec is not enough: specs frame, loops climb

If the path is knowable up front, write the spec. If it only shows itself through execution,
the spec frames a **hill climb** (see `operating-procedures.md` §6). Examples: getting the MDM
resolver to resolve every job definition against real job-search data, or finding the polling
interval that stays well inside rate limits.

## Review checklist for a proposal (Discover exit)

- [ ] The Why is stated, and every requirement traces to it.
- [ ] Every requirement has at least one Given/When/Then scenario, including a failure path.
- [ ] The five mandatory questions (constitution) are answered.
- [ ] Out of scope is written down.
- [ ] Each outcome is a check someone can run, not a declaration.
- [ ] It can be reviewed in one sitting. If not, split the change.

## Where an intent gap came from

When something turns out wrong, label where the intent was lost, and repair it at that point:

| Loss point | Meaning | Repair |
|---|---|---|
| Surfacing | Nobody asked the question (e.g. what the person sees when a run 429s) | Add the question to the constitution's mandatory questions or the proposal template |
| Capture | It was said but not written precisely | Strengthen the spec format (add a scenario) |
| Construction | It was written, but the code drifted | Standing constraint, lint rule, or review-guide item |
| Verification | No check caught it | Add a failing-first test |

A gap is confirmed fixed only when no new gap of the same class appears in the next two
changes.
