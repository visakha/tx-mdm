# Collaboration spine: how Vamsi and Muse build tx-mdm

Written 2026-11-23 at Vamsi's request: "the general direction, the gist of how we are
doing things... so that we understand the spine and the essence of our thought process
and how we are collaborating." Not a spec. The gist, kept short on purpose.

## The loop

1. Vamsi drives the real app on his laptop, against his real IDMC org, and says what he
   sees and wants, out loud, in plain words.
2. Muse reads it back in one or two sentences. If the read-back is wrong, he says
   "no, no, no" and corrects it; the correction wins and replaces the earlier ask.
3. Muse turns the ask into a short written brief (goal, his words, constraints, what is
   unverified) and a builder agent implements it.
4. Small version, every time: one bump of /api/about, three highlights, pushed, verified
   on GitHub (git ls-remote) before he is told "ready".
5. He pulls, restarts (start-backend.ps1 -Pull, start-frontend.ps1), looks, and the next
   ask comes from what he sees. Many small steps, not one big design up front.

## The spine (rules that do not bend)

- Backend first. Every UI action sits on a typed FastAPI endpoint visible in Swagger,
  grounded in a documented IDMC API. If IDMC cannot do it, it is left out and said so.
  The UI never fakes a capability.
- Strongly typed end to end. Pydantic models from metadata, TypeScript types generated
  from OpenAPI, a drift test that fails when they disagree. No stringly-typed data.
- Metadata drives the screens. Entities, fields, field groups and data types come from
  the org's metadata; config he edits by hand (b360_entities.toml) narrows what shows.
- Grounded, never invented. Facts come from the PDF, the KB, or a live read. Guesses are
  labelled UNVERIFIED. Missing things are flagged, not made up.
- The password never leaves his laptop. Muse reaches his backend over Tailscale; the
  backend holds the credentials. Tests use a fake IDMC; writes to the real org happen
  only when he presses the button.
- Honest status. Measured timings, real test counts, what was skipped (e.g. Cypress)
  and what is still unproven are said plainly.
- His words are the source of truth for meaning: master vs source, system fields vs
  record system metadata, ffr_ = freeform reason, taskflow naming, lowercase source ids.

## Taste

- Simple over clever. Stacked full-width panes, no tabs for field groups, no colour
  coding except where he asked (magenta for system items), no pop-ups anywhere.
- ASCII only. Commands always given as copyable text.
- Agent-friendly UI (Vercel UI SDK): labelled components so an agent can drive the same
  screens he does, through the bridge, the way a person would.
- Notes travel with the code: ui-observations, api-facts and gotchas are updated in the
  same commit as the change.

## Roles

- Vamsi owns the meaning, the domain and the priorities, and is the final check on his
  own screen.
- Muse owns the plumbing, the verification and the memory of what was decided, and says
  when something is a guess.

## Known gap (honest)

The spec-driven paperwork (specs/ and changes/ proposals) has not kept pace with the fast
voice-driven builds since the Monitor tab; the decisions live in the briefs and these
notes. Vamsi chose (2026-11-23) to capture the gist here rather than backfill per-version
proposals.
