# publish_dest, S10-only — notes

Regenerated 2026-11-17/18 at the user's request: the `publish_dest/` twins in
`Snowflake_All_Sources_Bare_Bones_v2.1_COMPILED_PUBLISH_DEST.zip` inlined the
whole WRK chain (`s20_active`, `s30_dq`, `s40_routed`, `s50_ready`, …).
This zip keeps **only the first (source) step** as a CTE — `s10_src` and its
per-source equivalents — and aliases every target column from it. The previous
zip is untouched; this is a separate file.

## Layout (same as the previous zip)

- The 391 base COMPILED-zip files, unchanged.
- `<SRC>/publish_dest/<file>.sql` — the 45 S10-only twins below (same paths as
  before, so this zip's `publish_dest/` holds the S10 versions only).
- `<SRC>/<SRC>_PUBLISH_DEST_S10_MAP.md` — per-twin column map: what each target
  column is aliased from, and which columns are NULL and why.
- `PUBLISH_DEST_S10_NOTES.md` (this file) and `COMPILE_REPORT_PUBLISH_DEST_S10.md`
  at the root.

## Twins: 45 C_S_* targets only

| source | twins | target columns | columns NULL |
| ------ | ----- | -------------- | ------------ |
| ECI    | 7     | 150            | 7            |
| FSS    | 7     | 145            | 9            |
| TTF    | 4     | 58             | 2            |
| WIC    | 6     | 129            | 4            |
| CRE    | 7     | 136            | 45           |
| TRS    | 14    | 345            | 80           |
| total  | 45    | 963            | 147          |

The other 92 publish files have no twin: 68 EXC (`EXC_STG_BAD_REC_MEMB`),
4 DQM_ADDRESS, and 20 staging / inactive-log / merge targets
(`STG_*_PTY_INACTIVE_LOG/STS`, `STG_TRS_D_UNQ_ADDR`,
`STG_TRS_DEACTIVED_MEMBERS`, `STG_TRS_VALID_MEMBERS`,
`STG_TRS_DEACTIVATED_RELATIONSHIPS`, `STG_ECI_D_FAMILY_ADDRESS/PHONE/MEDICAID`,
`CRE_SRC_MRG`). They are not C_S_* spine targets and their payload does not
exist in the first step at all. They are listed in the per-source maps.

First-step names are chain-specific, not always `s10_src`: ECI `s10_src` /
`s10_latest`, FSS `s1_src`, TTF `s1_active` / `s1_enriched` / `s1_keys` /
`s1_src`, WIC `s10_active` / `s10_enriched` / `s10_keys` / `s10_src`, CRE
`s1_src_mrg`, TRS `s1_src` / `s10_daily` / `s10_dedup` / `s10_keyed` /
`s10_minpk` / `s10_payee` / `s10_raw` / `s10_src`. The kept step is named in
each twin's header and map.

## How each target column is produced

Positional over the original INSERT's column list, using the original publish
file's final SELECT items, traced backwards through the chain to the first
step:

- **Passthrough** — the column is a first-step column, used as-is.
- **Helper stripped to its raw input** — a `fn_snow_helperNN_common(...)` call
  is DQ / lookup fluff; the value is its first column input. E.g. `std_phone`
  <- `fn_snow_helper23_common(PHONE_EMAIL)` becomes `PHONE_EMAIL`.
- **IFF / CASE guard dropped** — when the value branches agree on one raw
  column (the other branch being NULL / a literal), the guard is discarded
  and that column is used. A pure IFF / CASE whose refs all trace is kept
  whole instead (its guard is real logic, e.g. the 7-digit phone padding in
  the ECI PHN twin — see the example below).
- **Pure expression kept** — a helper-free expression (concatenation, `NVL`,
  `CAST`, arithmetic, `CASE`) is kept with its column refs rewritten to the
  first step. This is how spine keys built by concatenation survive, e.g.
  a `PTY_RLE_FK || '|' || …` key.
- **Variant field resolved** — `v:field` is resolved to the field's value,
  read from the `OBJECT_CONSTRUCT` or the helper body that built the variant
  (name / race / gender helpers 15 / 19 / 17), with the call's args
  substituted for the helper's parameters. E.g. `mdm_race_cd` becomes the
  `CASE` over the five race-indicator columns from the first step.
- **Literal / parameter kept** — a literal producer (`VERSION_SEQ '1'`,
  `HUB_STATE_IND 1`) or a `:parameter` producer (`:P_RUN_TS`) is kept.
- **Spine fallbacks** — `VERSION_SEQ` -> `'1'`, `HUB_STATE_IND` -> `1`, and a
  run-timestamp column (`LAST_UPDATE_DATE` / `CREATE_DATE` / `RUN_TS`) whose
  chain derives it from `:P_RUN_TS` -> `:P_RUN_TS`.
- **NULL** — the column cannot be produced from the first step (see below).
  Recorded per column in the maps.

`WITH` goes after the INSERT column list (`WITH` before `INSERT` is a
Snowflake syntax error). `P_RUN_TS` is appended to the procedure's parameters
iff the new SELECT references it and it is absent (all 45 twins need it;
TRS originals mostly already declare it). Original parameters are never
removed — TRS originals already declare `P_RUN_TS` and `:P_xxx` defaults,
CRE's `:P_xxx` literals are inlined at their driver defaults.

## The user's example (ECI PHN -> C_S_ECI_PTY_RLE_PHN, 14 columns)

```
WITH s10_src AS ( ... first step verbatim ... )
SELECT PKEY_SRC_OBJECT AS PKEY_SRC_OBJECT,
       PERIOD_START_DATE AS PERIOD_START_DATE,
       '1' AS VERSION_SEQ,
       :P_RUN_TS AS LAST_UPDATE_DATE,
       :P_RUN_TS AS CREATE_DATE,
       SRC_ROWID AS SRC_ROWID,
       PTY_RLE_FK AS PTY_RLE_FK,
       PHONE_TP AS PHN_TP,
       USG_TP AS USG_TP,
       (IFF(LENGTH(PHONE_EMAIL) = 7, '000' || PHONE_EMAIL, PHONE_EMAIL)) AS PHN_NUM,
       PREF_LVL AS PREF_LVL,
       PERIOD_START_DATE AS SRC_LAST_UPD_DT,
       WORK_EXT AS PHN_NUM_EXT,
       1 AS HUB_STATE_IND
  FROM s10_src;
```

`PHN_NUM` keeps the 7-digit padding rule (`IFF(LENGTH(...) = 7, '000' || …)`):
it is a value rule on the raw phone, not a DQ step, and it is reproducible
from the first step. Everything else is a bare first-step column, a literal,
or `:P_RUN_TS`. The gate (`grp_phone_good AND uq_phn`) is gone.

## What changes semantically (read before running)

- **No gate.** Inactive / invalid / duplicate rows land. TTF and WIC first
  steps already embed the inactive filter (their `s1_active` / `s10_active`
  read the staging view with the inactive check), so those twins still
  exclude inactive rows. ECI, FSS, CRE and TRS lose their separate ACTIVE
  step, so inactive rows land there.
- **Raw values, not standardized ones.** Phone, email, name, race and gender
  columns carry the raw first-step values. The DQ standardization (title
  case, junk-name blanking, race-code derivation, gender mapping) is gone,
  except where it reduces to a value rule reproducible from the first step
  (the race `CASE` over the five indicators, the 7-digit phone padding).
- **No dedup.** The `uq_*` / `ROW_NUMBER` dedup is gone, so a first-step row
  that the original would have deduped away now lands.
- **Timestamps and spine flags are literals.** `VERSION_SEQ` is `'1'`,
  `HUB_STATE_IND` is `1`, run timestamps are `:P_RUN_TS`. These were
  computed by the dropped steps.
- **Five first steps call a helper themselves.** TTF PHN, WIC PHN and WIC
  EADDR first steps standardize the phone / email inline (`helper23` /
  `helper22`); ECI ADR's first step has a lookup CTE (`helper41`); TRS
  REL2's first step uses `helper01` as a numeric check. That is the source
  step's own logic, kept verbatim — the helpers live in `00_common`, so
  `00_common` must be installed for those five twins to run.
- **CREATE-only validation.** As with the earlier compiles, `CREATE PROCEDURE`
  does not resolve object references or call arity inside procedure bodies;
  a wrong table name or argument count inside a body surfaces only at CALL.

## The NULLs (147 of 963 columns)

A NULL means the value does not exist in the first step. The clusters:

- **TRS ADDR2 — 34.** The first step is a dedup holding keys only
  (`s10_dedup`: `INDV_ID`, `CASE_NUM`, `EDG_NUM`, `ADDR_TYPE_CD`, `ADDR_ID`,
  dates); the whole address payload enters at step 2 (`s20_src`), joined
  from the staging tables `STG_TRS_D_UNQ_ADDR` and `STG_TRS_VALID_MEMBERS`.
  Even the spine keys are NULL here.
- **TRS PHN — 10, TRS EADDR — 7, TRS ALT — 10.** A table-function unpivot
  expands one first-step row into several target rows
  (`fn_snow_helper01_m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr` for phones,
  the alt-id slots for ALT). One first-step row cannot express that as a
  single SELECT; a `UNION ALL` over the first step (one branch per slot)
  would be needed. Not built here.
- **CRE ADDR — 18.** AddressDoctor-scored fields (second line, state,
  country, latitude/longitude, mailability, building/sub-building parts,
  geocode status, org name/desc, validation message) are not in the first
  step (`s1_src_mrg`).
- **CRE timeline — PERIOD_END_DATE / PERIOD_REFERENCE_TIME / TIMELINE_ACTION**
  in the CRE PTY / PTY_RLE / ALT twins. Computed by the dropped timeline
  steps, not present in the first step.
- **Lookup-derived codes** — `ETHNCTY`, `PRFRD_LANG_CD`, `RACE_CD` in some
  PTY twins, `REL_TYPE_CODE` / `HIERARCHY_CODE` in TRS REL1, `REL_TYPE_CODE`
  in TRS REL2. They come from `V_LOOKUP_CODE_VALUE` joins in the dropped
  steps, not from the first step.
- **TRS REL / PLN / TOA keys — 3–5 each.** `PKEY_SRC_OBJECT` / `SRC_ROWID`
  (and `PTY_RLE_FK_2`, `PLN_FK`, `TOA_FK`) are assembled in the dropped
  keyed / timeline steps from values the first step does not carry.
- The remaining NULLs are single columns (ECI/FSS/WIC ADR `COUNTY`,
  ECI/FSS/WIC EADDR `ELEC_ADDR`, FSS PHN `PHN_NUM_EXT`, a few CRE/TRS
  name/timeline columns). Every one is listed per twin in the maps.

Columns that were already NULL in the original publish files (e.g.
`ROWID_OBJECT`, `DELETED_IND/DATE/BY`, `UPDATED_BY`, `CREATOR` in several
TRS twins) are kept verbatim as NULL and are **not** counted in the 147.

## Verification

- Structural verifier `publish_dest_work/check_s10_twins.py`: **45/45 PASS**
  (same filename, C_S_* target, INSERT target + columns identical to the
  original, SELECT item count == target column count with each item aliased
  `AS` its target, exactly one CTE whose name and body match the previous
  twin's first CTE verbatim, every SELECT reference an output of the kept
  CTE, no unbound `:variables`, no `WRK_` in code, no `;;`).
- Live compile `snow_compile/compile_s10_key.py`: **45/45 OK, 0 errors**,
  scratch database `S10_COMPILE_DB`, CREATE only, no CALLs, no existing data
  touched. Full report: `COMPILE_REPORT_PUBLISH_DEST_S10.md`.
- Two live-compile bug classes were found and fixed at generator level
  during this build: (1) a multi-line WHERE gate embedded in a twin header
  broke out of its `--` comment and left a stray `ON …` fragment before the
  `CREATE` (3 TRS twins); (2) `SELECT DISTINCT` in a step was parsed as
  part of the first column's expression, leaking a bare `DISTINCT` into
  reduced expressions (`TO_VARCHAR((DISTINCT INDV_ID))`, 2 TRS twins).

## Generators / verifiers (kept in the workspace, not in the zip)

- `~/workspace/publish_dest_work/build_s10_publish_dest.py` — the generator
  (backward column trace with expression keeping and variant-field
  resolution against the helper catalogue in
  `00_common/01_snow_common_functions.sql`).
- `~/workspace/publish_dest_work/check_s10_twins.py` — structural verifier.
- `~/workspace/snow_compile/compile_s10_key.py` — live-compile harness.
- Per-source staging: `~/workspace/publish_dest_work/<SRC>/publish_dest_s10/`
  and `~/workspace/publish_dest_work/<SRC>/<SRC>_PUBLISH_DEST_S10_MAP.md`.
