# PHN Manifest - m_Tgt_C_S_TTF_Pty_Rle_Phn, bare-bones variant (TTF ONLY)

Bare-bones strip of the v2.1 step-driver code: no config table, no
checkpointing, no job-run id, no input-existence checks, no per-step
gating. Business SQL (step CTAS bodies, publish INSERT bodies) is
verbatim from v2.1. Work tables are TRANSIENT and are dropped by
step 5 at the start of a run and left standing at the end.

## Driver

```sql
sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn (
) RETURNS VARCHAR
```

File: `drivers/driver_sp_snow_main_m_Tgt_C_S_TTF_Pty_Rle_Phn.sql`

## Steps

| Step | Proc | Produces | Consumes |
|---|---|---|---|
| 10 | `sp_snow_step_TTF_PHN_S10_SRC` | `WRK_TTF_PHN_S1_SRC` | `(base source tables)` |
| 20 | `sp_snow_step_TTF_PHN_S20_CHECKED` | `WRK_TTF_PHN_S2_CHECKED` | `WRK_TTF_PHN_S1_SRC` |
| 30 | `sp_snow_step_TTF_PHN_S30_ROUTED` | `WRK_TTF_PHN_S3_ROUTED` | `WRK_TTF_PHN_S2_CHECKED` |

Step proc signatures: the step's used original parameters (in original
order) + `P_RUN_TS`. Only `sp_snow_step_TTF_PTY_S40_ROUTED` has
original parameters; its `P_RUN_TS` carries DEFAULT NULL because the
preceding original parameters carry defaults (Snowflake forbids a
required parameter after an optional one; drivers pass positionally,
so behaviour is unchanged). Every step proc returns NUMBER (row
count), has no exception block, no transaction, no target write.

## Publish branches (one transaction, in order)

| Step | Proc | Kind | Target | Consumes | Keeps P_RUN_TS |
|---|---|---|---|---|---|
| 40 | `sp_snow_pub_TTF_PHN_C_S_TTF_PTY_RLE_PHN` | SPINE | `C_S_TTF_PTY_RLE_PHN` | `WRK_TTF_PHN_S3_ROUTED` | N |
| 50 | `sp_snow_pub_TTF_PHN_EXC_STG_BAD_REC_MEMB` | EXCEPTION | `EXC_STG_BAD_REC_MEMB` | `WRK_TTF_PHN_S3_ROUTED` | N |

Branch proc signatures: only the branch whose INSERT body references
the run-timestamp parameter keeps `P_RUN_TS` (see table); all other
branches take no parameters. A `run_ts` column read from the final routed
work table does NOT count as keeping it. Each branch returns
`SQLROWCOUNT` as NUMBER and contains no transaction control.

## Summary flow

The driver builds `l_summary` with `fn_snow_helper36_common` as each
step and each publish branch returns, and RETURNs `l_summary`.
Publish branch counts flow through the reused `l_rows` variable with
an immediate summary append inside the publish transaction (variable
assignment only, no checkpoint, no transaction effect). On error the
driver exception block does ROLLBACK + RAISE only, and work tables
are left in place until the next run's step 5 cleanup. The workflow
runner calls each driver with zero arguments, captures each RETURN
string, concatenates it under a per-mapping header line, and RETURNs
the one combined summary string.

Not tested: no live Snowflake compile, run, or row-count parity run
was possible in this environment; that step is required before use.
