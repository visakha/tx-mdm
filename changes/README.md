# changes/ — one folder per change proposal

```
changes/
  _templates/            copy these to start a change
  NNN-<slug>/            an open change: proposal.md, specs/<area>.md, design.md, tasks.md
  archive/NNN-<slug>/    finished changes (their spec deltas are already merged into ../specs/)
```

How a change moves (full rules in `../methodology/sdd-lifecycle.md`):

1. **Discover**: copy `_templates/` to `NNN-<slug>/` (next free number), and write
   `proposal.md` and `specs/`. Get Vamsi's go.
2. **Design**: write `design.md`.
3. **Tasks**: write `tasks.md`. Acceptance tests come first.
4. **Implement**: follow `tasks.md` and `../methodology/operating-procedures.md`.
5. **Converge**: a separate verification pass writes its verdict at the end of `tasks.md`.
6. **Archive**: merge the spec deltas into `../specs/` and move the folder to `archive/`.

Filing rule: if it must survive throwing the code away, it goes in `specs/`; otherwise it
goes in `design.md`.

No change is open yet. The baseline (CDI, MDM, agent interface, proxy policy) was built before
this flow existed. It is recorded directly in `../specs/` (state: Reconciled) and in
`../methodology/decisions.md` D1–D11.
