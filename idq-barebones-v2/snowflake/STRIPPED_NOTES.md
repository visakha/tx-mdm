# STRIPPED_NOTES - what was removed from v2.1, and what stayed

Bare-bones variant of `Snowflake_All_Sources_Modular_Step_Driver_v2.1`.
The strip was mechanical: delete the control plane, keep the structure
and the business SQL. Nothing below changes a CTAS or an INSERT.

## The removal list (exact)

1. **Config table gone.** No `COMMON.ETL_RUN_CONFIG_TBL`, no GATHER
   block, no Y/N flags, no driver-row gate, no seed files. A driver
   no longer asks anything at runtime - it runs every step and every
   branch, in order, every time.
2. **Checkpointing gone.** No `sp_etl_checkpoint`,
   `sp_etl_job_begin`, `sp_etl_job_finish`, `sp_etl_job_fail` calls,
   and no job-control DDL/procs or config DDL. There is no COMMON
   schema in this package.
3. **Run-id and input tables gone.** No `P_JOB_RUN_ID`,
   `P_INPUT_TABLES`, `l_job_run_id`, `l_flag_*`, `l_in_*`,
   `l_pub_*` in any code line. (Headers may mention the removals in
   comments; code lines are clean - verified by grep.)
4. **Existence checks gone.** No INFORMATION_SCHEMA input-table checks,
   no EXECUTE IMMEDIATE probe blocks in steps or publish procs. A
   missing work table now fails natively at the CTAS/INSERT instead
   of at a pre-check.
5. **Seed files gone.** No `seed_*.sql` anywhere.
6. **Config/job-control docs gone.** No config columns in DEPENDENCIES
   or STEP_MAP; manifests are slim and carry no Mermaid diagrams.

## Before / after per proc kind

### Driver (`driver_sp_snow_main_*`)

Before (v2.1): original params + `P_JOB_RUN_ID`; job-begin; GATHER
from the config table; driver-row gate; step-5 cleanup; conditional
step calls with SKIPPED arms; one publish transaction; branch
checkpoints after COMMIT; job-end; exception -> checkpoint + job-fail.

After (bare-bones): original params only. No job-begin, no GATHER, no
gate. Step-5 bare `DROP TABLE IF EXISTS` cleanup, unchanged. Step
calls UNCONDITIONAL, in order:

```sql
l_rows := (CALL sp_snow_step_<PREFIX>_S<nn>_<NAME>(<original args>, :l_run_ts));
l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step <nn> <NAME>', :l_rows) || CHR(10);
```

Publish: `BEGIN` -> branch calls in order (each followed immediately
by its summary append, reusing `l_rows` - string concatenation only)
-> `COMMIT`. Exception: `ROLLBACK` + `RAISE` only. Ends with
`RETURN l_summary`.

### Step (`sp_snow_step_*`)

Before (v2.1): original-used params + `P_JOB_RUN_ID` + `P_RUN_TS` +
`P_INPUT_TABLES`; existence check + probe; CTAS; checkpoint; RETURN
rowcount.

After: original-used params + `P_RUN_TS` only. No existence check, no
probe, no checkpoint. CTAS verbatim, RETURN rowcount unchanged.
`P_RUN_TS` is kept in every step (steps use it in their CTAS, or
carry it unused under the uniform rule). Where an original param
carries a DEFAULT before `P_RUN_TS`, the step gives `P_RUN_TS`
DEFAULT NULL too (Snowflake forbids required-after-optional; drivers
pass positionally, so behaviour is unchanged). Added in this strip:
WIC ADR S40 + PTY S40, TTF PTY S40, CRE S40 + S50. Already present in
v2.1 and retained: TRS steps (all), ECI ADR S50 + PTY S50, FSS ADR S40
+ PTY S40.

### Publish branch (`sp_snow_pub_*`)

Before (v2.1): original-used params (where the INSERT uses them) +
`P_JOB_RUN_ID` + `P_RUN_TS` + `P_INPUT_TABLES`; existence check in
some; INSERT; RETURN rowcount.

After: original-used params + `P_RUN_TS` ONLY where the INSERT
references `:P_RUN_TS` directly. A `run_ts` column read from a step
table does not count. Branches keeping `P_RUN_TS`: TRS 27 of 38, WIC
1 of 19 (ALT), TTF 1 of 13 (ALT), FSS 1 of 23 (ALT), ECI 0 of 26, CRE
0 of 18. All other branches take zero parameters (plus any original
params their INSERT uses). No existence checks. INSERT verbatim,
RETURN rowcount unchanged.

### Runner (`sp_etl_run_*`)

Before (v2.1): took `P_JOB_RUN_ID`, passed it to each driver.

After: no parameters. Calls each driver with zero arguments,
concatenates each returned string with a per-mapping header line and
newlines, RETURNs the combined string. Run scripts (`run_*.sql`) CALL
the runner with no arguments; otherwise unchanged. Runner errors
propagate - runners own no transaction; each driver rolls back its
own publish transaction on failure.

### Common helpers (`00_common/`)

Unchanged, byte-identical to v2.1: `01_snow_common_functions.sql`
and `02_snow_common_lookups.sql`. They are business functions, not
logging. `fn_snow_helper36_common` formats the summary lines; the
lookup UDFs still need the seven real reference objects (see README).

## Counts live only in the summary string

Steps and branches still RETURN their row counts, drivers format them
into `l_summary`, runners concatenate. NOTHING is written to any
table. If the caller does not capture the returned string, the counts
are gone. There is no audit trail, no resume, no per-step status to
query afterwards - that is the point of this variant, and its limit.
Work tables are still left standing after a run (step 5 of the next
run drops them), so a failed run's intermediate tables can still be
inspected by hand.

## Special cases

- **TRS party-deactivation step 50** (`DELETE_VALID_STAGE_NOT_PERFORMED`)
  had no business SQL - its only action was a checkpoint. It is kept
  as a proc that just `RETURN`s 0, still called after the publish
  transaction, so the step count (66) and the summary line survive.
- **No step SQL anywhere referenced `P_JOB_RUN_ID`.** In every source,
  the only `P_JOB_RUN_ID` occurrences in step files were the signature
  and the checkpoint call - both removed. No call site anywhere passed
  arguments beyond (originals, job, run-ts, consumed-string).
- **Branch summary placement (uniform across all six sources).**
  v2.1 appended branch summaries after `COMMIT` from `l_pub_*`
  variables, which this variant deletes. Every source now appends
  each branch's line immediately after its call inside the
  transaction, reusing `l_rows`. The returned string is unchanged in
  content and order versus v2.1. (One worker initially kept
  post-`COMMIT` appends under renamed `l_cnt_*` variables; that was
  normalized to the in-transaction pattern during assembly so all six
  sources read the same way.)

## How to run (Windows)

From Windows Command Prompt (`cmd`; PowerShell also accepts `>`
redirection), calling the TTF workflow runner and logging its
returned summary string to a file:

```
snowsql -a DOOPELI-LL99227 -u VIZY --authenticator SNOWFLAKE_JWT --private-key-path C:\keys\vizy_rsa_key.p8 -r ACCOUNTADMIN -w SNOWFLAKE_LEARNING_WH -d MDM_ETL_TTF -s TTF_ETL_WRK -q "CALL sp_etl_run_wf_TTF_Stage_Load();" > C:\logs\ttf_stage_load.log 2>&1
```

- The private key file must be a copy on the Windows machine (the
  compile machine's copy is not reachable from Windows); the key is
  unencrypted so no passphrase is needed.
- `-d` / `-s` / `-w` are the install database / schema / warehouse -
  adjust to the actual install (the example uses the package's
  documented TTF topology).
- The runner takes no arguments and RETURNs the combined summary
  string; snowsql prints the result and `>` captures it into the log
  file (optionally add `-o output_format=csv -o header=False` for a
  bare value instead of the formatted table, if the installed snowsql
  version accepts those options).
- Flag names verified against Snowflake's snowsql docs
  (`-a` / `-u` / `-d` / `-s` / `-w` / `-q` / `-o` /
  `--private-key-path` / `--authenticator SNOWFLAKE_JWT`).

## Install rule

Install EVERYTHING for one source - its drivers, steps, publish
procs, AND both helper files - into ONE schema, because drivers call
helpers unqualified. The RDM reference data for the lookups is
separate; the seven reference objects still need real definitions
before a production install (see README).

## What is NOT validated

No live Snowflake compile, run, or row-count parity was performed for
this package. Static verification only (see README). Compile-time
items still to confirm on first run: the scalar-call capture form
`l_rows := (CALL proc(...));`, zero-argument calls to drivers with
defaulted params, and zero-argument publish calls.
