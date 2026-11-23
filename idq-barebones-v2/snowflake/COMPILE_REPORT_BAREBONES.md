# COMPILE REPORT — both bare-bones packages

Validated 2026-10-27 against the user's Snowflake account (key-pair auth,
VIZY / ACCOUNTADMIN), compile-only: CREATE statements executed, no
procedure CALLed, no existing data touched. The ECI v2.1 scratch database
(`ECI_V2_COMPILE_DB`) was left untouched; this run used a fresh scratch
database, `BAREBONES_COMPILE_DB`, left in place for inspection.
Harness: `workspace/snow_compile/compile_barebones_key.py`.

## Result: 360/360 files OK, 0 errors, 661 statements

| Package | Schema | Files | Result |
|---|---|---|---|
| All-sources bare-bones | TRS | 121 + 2 helpers | OK |
| All-sources bare-bones | ECI | 68 + 2 helpers | OK |
| All-sources bare-bones | WIC | 42 + 2 helpers | OK |
| All-sources bare-bones | TTF | 30 + 2 helpers | OK |
| All-sources bare-bones | FSS | 51 + 2 helpers | OK |
| All-sources bare-bones | CRE | 25 + 2 helpers | OK |
| Deactivation bare-bones | DACT | 5 mappings + 4 runners + 2 helpers | OK |

Install topology mirrored each package's own rule: one schema per source,
helpers installed into the same schema (all calls are unqualified).
Skipped, by design: the 11 `run_*.sql` snowsql wrappers (their only SQL is
a zero-argument CALL; CALLs are out of scope for a compile-only run), plus
`.md` docs and `.dot` / `.svg` / `.png` diagrams.

## Inventory (scratch database, via SHOW commands)

| Schema | Procedures | Functions | Tables |
|---|---|---|---|
| TRS | 121 | 45 | 6 |
| ECI | 68 | 45 | 6 |
| WIC | 42 | 45 | 6 |
| TTF | 30 | 45 | 6 |
| FSS | 51 | 45 | 6 |
| CRE | 25 | 45 | 6 |
| DACT | 9 | 45 | 6 |
| RDM | 0 | 0 | 1 |

Procedure counts match install-file counts exactly per schema. 45 functions
per schema = 37 common helpers + 8 lookup UDFs. Tables are the scratch-only
stubs below. `SHOW` also lists Snowflake's own built-ins with a blank
schema (30 procedures, 1152 functions) — those are not package objects.
Note: the fully-qualified `INFORMATION_SCHEMA.ROUTINES` form failed with
error 002003 in this session, so the inventory was taken with `SHOW`
commands instead; that failure is about the query form, not the install.

## Code changes: none

Zero errors means the code in the original bare-bones zips compiled as-is.
No file was modified for this validation. These `_COMPILED` zips therefore
contain code identical to the original bare-bones zips, plus this report.
(The one compile class that needed fixes last time — required-after-optional
parameters — does not occur here: the bare-bones strips already carry
`DEFAULT NULL` where the rule required it.)

## Static checks supporting runtime calls (unchanged code)

- All 40 all-sources drivers: every parameter carries a `DEFAULT`, so the
  runners' zero-argument calls are statically safe.
- Deactivation mappings: four take no parameters; History Audit takes its
  two IDQ parameters (both defaulted), and its runner passes `('012',
  '007')` explicitly.
- Call-site arity was verified statically when the bare-bones packages
  were built (330 all-sources call sites, 0 bad; 5 deactivation runner
  calls hand-checked) and the code has not changed since.

## Honest limits — what this run does NOT prove

- `CREATE PROCEDURE` does not resolve object references or call arity
  inside procedure bodies at creation time. A wrong table name or a wrong
  argument count inside a body would surface only at runtime (CALL).
- No procedure was CALLed, so there is no runtime behaviour or row-count
  parity evidence. That still needs source data in a non-production
  database.
- The 7 reference objects the lookup UDFs need (`V_LOOKUP_CODE_VALUE`,
  `REF_JUNK_NAME_LIST`, `REF_MATCHCODE_DESC`, `RDM.REF_PHN_AREA_CD`,
  `EXC_LOOKUP_CODE_VALUE`, `LOOKUP_CODE_VALUE`, `REF_DYLGHT_SVNGS_TM`)
  were validated against scratch-only stubs (columns taken from the UDFs'
  own SELECT lists, same as the v2.1 validation). The stubs are NOT
  shipped; real definitions are still needed before production install.
- The deactivation runners' scalar-call capture form
  (`l_map := (CALL proc(...))`) compiled cleanly here in all 4 runners,
  as it did for the v2.1 drivers — but its runtime behaviour is still
  unproven until a first CALL.
