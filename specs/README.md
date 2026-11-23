# specs/ - current state

This folder describes what tx-mdm does **today**. It changes only when a change proposal
under `../changes/` is archived. In each file, every requirement has an id (`FR-...`), at least
one scenario, and a status: `CODE` (implemented and tested offline) or `LIVE` (also seen
against the real org).

| File | Area |
|---|---|
| [`cdi.md`](cdi.md) | Data Integration: task list, run, monitor |
| [`mdm.md`](mdm.md) | Business 360: job definition list, id resolution, run, monitor |
| [`shared.md`](shared.md) | Session, run rules, results screen (common to both) |
| [`agent-interface.md`](agent-interface.md) | Routes, `window.txmdm` actions, test ids, OpenAPI contract |
