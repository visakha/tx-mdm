# specs/ - what tx-mdm does today (as of 0.9.11, commit 68aa953)

These files describe CURRENT behaviour, short and checkable. One line per requirement where
possible; each requirement names the backend route that serves it (API-first: no UI feature
without a typed endpoint in Swagger).

Status tags:
- `CODE` - built and covered by tests against the fake IDMC (`backend/dev/fake_idmc.py`).
- `LIVE` - also seen working against Vamsi's real org.
- `UNVERIFIED` - shape taken from the docs or a guess; not yet proven live.

| File | Area |
|---|---|
| [`shared.md`](shared.md) | Shell, run rules, polling, typed contract, no pop-ups, about, start-up |
| [`cdi.md`](cdi.md) | Data Integration: tasks, taskflows, monitor, naming rule |
| [`mdm.md`](mdm.md) | Business 360 jobs: runs, Currently running, MDM taskflows |
| [`b360-data.md`](b360-data.md) | B360 Data notebook: master vs source records, metadata, add, edit |
| [`design.md`](design.md) | Design notebook: CDI asset types, metadata, runtime env; IDMC portal links |
| [`agent-interface.md`](agent-interface.md) | window.agent, window.txmdm, labels, what agents cannot do |

How these relate to the rest of the repo:
- `methodology/constitution.md` - the rules every spec must obey (backend owns IDMC, typed,
  ASCII, public-repo hygiene). Specs never override it.
- `internal-notes/collaboration-spine.md` - HOW we work (voice ask -> read-back -> brief ->
  small version -> his screen). Specs are WHAT the result does.
- `internal-notes/api-facts.md` - which IDMC calls are documented / LIVE / UNVERIFIED. Specs
  point there instead of repeating proofs.
- `internal-notes/ui-observations.md` - per-version screen detail (test ids, click order).
- `changes/` - proposal folders. NOTE: 0.8.0-0.9.11 were built from voice briefs without change
  folders; these specs were brought up to date afterwards (2026-11-23) to close that gap.
