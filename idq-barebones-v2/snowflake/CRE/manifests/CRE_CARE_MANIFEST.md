# CRE_CARE Manifest - m_Tgt_C_S_CRE_CARE_Clients, bare-bones step-driver variant (CRE ONLY)

Prefix: `CRE_CARE`. Base dir: `snowflake_all_barebones/CRE/`.

Bare-bones variant of the v2.1 config-driven step-driver package: no
`ETL_RUN_CONFIG_TBL`, no job-control/checkpoint calls, no `P_JOB_RUN_ID`,
no `P_INPUT_TABLES`, no flag/input/publish variables, no seed file. The
driver runs every step and every publish branch unconditionally, in order,
and RETURNs the big summary string built with `fn_snow_helper36_common`.
Business SQL (step CTAS bodies, publish INSERT bodies) is verbatim from
v2.1; only the dropped parameters, existence-check/probe blocks, and
checkpoint calls were removed. A restart is simply a new run: step 5 drops
the previous run's work tables, then every step runs fresh. Work tables are
TRANSIENT and are left standing at the end of a run.

Workflow: `wf_CRE_Stage_Load_Ongoing`. Mapping: `m_Tgt_C_S_CRE_CARE_Clients`
(the workflow's only mapping). Install schema: `CRE_ETL_WRK` in database
`MDM_ETL_CRE`; all table names are unqualified.

## Driver

File: `drivers/driver_sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients.sql`

```sql
sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients (
    P_PHYSICAL_ADDR_TYPE_CD  VARCHAR DEFAULT '002',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_DEFAULT_TX_STATE_CD    VARCHAR DEFAULT '48',
    P_COUNTY_CD_NONTX        VARCHAR DEFAULT '996',
    P_COUNTYCD_DEFAULTALL    VARCHAR DEFAULT '998',
    P_DEFAULT_NONUS_STATE_CD VARCHAR DEFAULT '99'
) RETURNS VARCHAR
```

Driver behaviour: step 5 cleanup (5 bare `DROP TABLE IF EXISTS`, unchanged
from v2.1); unconditional step calls in order, each followed by its
`fn_snow_helper36_common` summary append; ONE publish transaction calling
all 18 branch procs in order, each followed by its summary append, then
`COMMIT`; exception block is `ROLLBACK` + `RAISE` only; ends with
`RETURN l_summary`.

## Steps

| Step | Proc | Produces (work table) | Consumes | Signature |
|---|---|---|---|---|
| 5 | _(cleanup, in driver)_ | - (drops all 5 work tables) | - | - |
| 10 | `sp_snow_step_CRE_CARE_S10_SRC_MRG` | `WRK_CRE_CARE_S1_SRC_MRG` - CARE snapshot + merge routing | _(none - base source tables)_ | `(P_RUN_TS TIMESTAMP_NTZ)` |
| 20 | `sp_snow_step_CRE_CARE_S20_NAMED` | `WRK_CRE_CARE_S2_NAMED` - standardised names + member validity | `WRK_CRE_CARE_S1_SRC_MRG` | `(P_RUN_TS TIMESTAMP_NTZ)` |
| 30 | `sp_snow_step_CRE_CARE_S30_RANKED` | `WRK_CRE_CARE_S3_RANKED` - rank + validation enrichment | `WRK_CRE_CARE_S2_NAMED` | `(P_RUN_TS TIMESTAMP_NTZ)` |
| 40 | `sp_snow_step_CRE_CARE_S40_FLAT` | `WRK_CRE_CARE_S4_FLAT` - flattened load-ready rows | `WRK_CRE_CARE_S3_RANKED` | `(P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member', P_DEFAULT_NONUS_STATE_CD VARCHAR DEFAULT '99', P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL)` |
| 50 | `sp_snow_step_CRE_CARE_S50_KEYED` | `WRK_CRE_CARE_S5_KEYED` - route flags + unique-key guards | `WRK_CRE_CARE_S4_FLAT` | `(P_PHYSICAL_ADDR_TYPE_CD VARCHAR DEFAULT '002', P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member', P_DEFAULT_TX_STATE_CD VARCHAR DEFAULT '48', P_COUNTY_CD_NONTX VARCHAR DEFAULT '996', P_COUNTYCD_DEFAULTALL VARCHAR DEFAULT '998', P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL)` |

Step files: `steps/sp_snow_step_CRE_CARE_S<nn>_<NAME>.sql` (5 files).
Every step proc returns `NUMBER` (row count). Steps 10/20/30 do not use
`P_RUN_TS` in their CTAS bodies (carried for a uniform driver call
signature); steps 40 and 50 use `:P_RUN_TS` directly. Steps 40 and 50
carry `DEFAULT NULL` on `P_RUN_TS` because their original parameters carry
defaults (Snowflake forbids a required parameter after an optional one;
drivers pass all parameters positionally, so behaviour is unchanged).
No step SQL references `P_JOB_RUN_ID` (in v2.1 it appeared only in the
step signature and its checkpoint call, both removed).

## Publish branches

Original publish was one step with 18 INSERTs in one transaction. Each
INSERT is one branch proc, called by the driver inside ONE transaction in
the same order. No branch keeps `P_RUN_TS`: every branch INSERT reads the
`run_ts` / `mapping_name` columns materialised in step 50 and references
neither an original parameter nor the run timestamp directly, so every
branch proc takes zero parameters and returns `SQLROWCOUNT` as `NUMBER`.

| Step | Proc | Target | Keeps P_RUN_TS | Original branch | Guard |
|---|---|---|---|---|---|
| 60 | `sp_snow_pub_CRE_CARE_CRE_SRC_MRG` | `CRE_SRC_MRG` | N | 60a | `grp_mrg` |
| 70 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_FIRST_NAME` | `EXC_STG_BAD_REC_MEMB` | N | 60b | `grp_first_name AND uq_first_name` |
| 80 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_LAST_NAME` | `EXC_STG_BAD_REC_MEMB` | N | 60c | `grp_last_name AND uq_last_name` |
| 90 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY` | `C_S_CRE_PTY` | N | 60d | `is_member AND uq_pty` |
| 100 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE` | `C_S_CRE_PTY_RLE` | N | 60e | `is_member AND uq_rle` |
| 110 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_GENDER` | `EXC_STG_BAD_REC_MEMB` | N | 60f | `grp_gender` |
| 120 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SUFFIX` | `EXC_STG_BAD_REC_MEMB` | N | 60g | `grp_suffix` |
| 130 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ETHNICITY` | `EXC_STG_BAD_REC_MEMB` | N | 60h | `grp_ethnicity` |
| 140 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_RACE` | `EXC_STG_BAD_REC_MEMB` | N | 60i | `grp_race` |
| 150 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ADDR` | `C_S_CRE_PTY_RLE_ADDR` | N | 60j | `grp_addr AND uq_addr` |
| 160 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ADDR` | `EXC_STG_BAD_REC_MEMB` | N | 60k | `grp_addr_exc` |
| 170 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_PHN` | `C_S_CRE_PTY_RLE_PHN` | N | 60l | `grp_phone AND uq_phone` |
| 180 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_PHONE` | `EXC_STG_BAD_REC_MEMB` | N | 60m | `grp_phone_exc` |
| 190 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_CARE` | `C_S_CRE_PTY_RLE_ALT_ID` | N | 60n | `grp_care_alt AND uq_care_alt` |
| 200 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_MEDICAID` | `C_S_CRE_PTY_RLE_ALT_ID` | N | 60o | `grp_medicaid_alt AND uq_medicaid_alt` |
| 210 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_MEDICAID_ALT` | `EXC_STG_BAD_REC_MEMB` | N | 60p | `grp_medicaid_exc AND uq_medicaid_exc` |
| 220 | `sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_SSN` | `C_S_CRE_PTY_RLE_ALT_ID` | N | 60q | `grp_ssn_alt AND uq_ssn_alt` |
| 230 | `sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SSN_ALT` | `EXC_STG_BAD_REC_MEMB` | N | 60r | `grp_ssn_exc AND uq_ssn_exc` |

Branch files: `publish/sp_snow_pub_CRE_CARE_*.sql` (18 files).
Publish targets (7): `CRE_SRC_MRG`, `C_S_CRE_PTY`, `C_S_CRE_PTY_RLE`,
`C_S_CRE_PTY_RLE_ADDR`, `C_S_CRE_PTY_RLE_PHN`, `C_S_CRE_PTY_RLE_ALT_ID`,
`EXC_STG_BAD_REC_MEMB`. Spine path: the `C_S_*` writes (steps 90, 100,
150, 170, 190, 200, 220) plus the merge-routing `CRE_SRC_MRG` write
(step 60, kind STATUS); non-spine path: the `EXC_STG_BAD_REC_MEMB`
exception writes (all other branches).

## Runner

File: `runners/sp_etl_run_wf_CRE_Stage_Load_Ongoing.sql`.
Run script: `runners/run_wf_CRE_Stage_Load_Ongoing.sql`.

```sql
sp_etl_run_wf_CRE_Stage_Load_Ongoing () RETURNS VARCHAR
```

The runner takes no parameters, calls the driver with zero arguments,
captures its RETURN string, prefixes it with the header line
`wf_CRE_Stage_Load_Ongoing`, and RETURNs it. The run script CALLs the
runner with no arguments.

## Summary flow

Driver RETURNs `l_summary`: one `fn_snow_helper36_common` line per step
(steps 10-50) and per publish branch (steps 60-230), in execution order,
each line carrying that unit's row count. The runner concatenates its
header line and the driver's summary and RETURNs the combined string.
There is no job-control table and no checkpoint row in this variant; the
summary string is the only per-run record.
