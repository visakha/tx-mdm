# barebones-v2 and the CDI side

`idq-barebones-v2/` is a read-only snapshot of the Snowflake bare-bones package from
github.com/visakha/idq-cli at commit `adde845`. Its README has the provenance. These notes say
how that package relates to the CDI jobs this app runs. The projects stay separate on purpose,
so tx-mdm can approach the CDI side fresh. Nothing in `backend/` or `frontend/` depends on these
SQL files.

## The relationship in one paragraph

The CDI jobs that tx-mdm lists and runs move the same MDM-load data: the six sources ECI, FSS,
TTF, WIC, TRS and CRE, from staging into the C_S_* tables. The barebones-v2 package is the
Snowflake rewrite of that load. The CDI design, as shown in `idq-barebones-v2/deck/` ("The Init
SQL — three sources, one pattern"), has every ETL pull from three SQLs:

- the **init SQL** — the S10 `publish_dest/` twins
- an **activation** SQL — `publish_reactivate/`
- a **deactivation** SQL — `publish_deactivate/`

So when a CDI run's counts look wrong, these files are where to read what the job is meant to do.

## Which tables

| Package part | Count | Writes to | Reads from |
|---|---|---|---|
| `*/publish_dest/` (S10 init SQL) | 45 twins: ECI 7, FSS 7, TTF 4, WIC 6, TRS 14, CRE 7 | **C_S_*** tables, e.g. `C_S_ECI_PTY`, `C_S_ECI_PTY_RLE`, `C_S_ECI_PTY_RLE_ADDR`, `C_S_TRS_PTY_RLE_REL_PROV`, `C_S_LU_TOA` | the first step's staging source only (`STG_*` / `_D_` / `_SN_` tables and `V_*_ETL_SRC` views) |
| `*/publish_deactivate/` | 10 (ECI 2, FSS 2, TTF 2, WIC 2, TRS 2) | **STG_*** tables, e.g. `STG_ECI_PTY_INACTIVE_LOG`, `STG_TRS_DEACTIVED_MEMBERS` | staging |
| `*/publish_reactivate/` | 7 (ECI 4, FSS 1, TTF 1, WIC 1) | **STG_*** tables, e.g. `STG_ECI_D_FAMILY_ADDRESS`, `STG_WIC_PTY_INACTIVE_STS` | staging |
| `*/drivers`, `steps`, `publish`, `runners` | 40 drivers | the full WRK-chain bare-bones load | staging |

Some details:

- The 42 distinct C_S_* names are listed by `grep -rhoE '\bC_S_[A-Z0-9_]+\b' idq-barebones-v2/snowflake --include=*.sql | sort -u`.
- `sheets/PKEY_SRC_OBJECT_Lineage.xlsx` traces each C_S_* PKEY back to its staging origin.
- The deactivate/reactivate twins write STG_* tables, not C_S_* tables. That is the state of
  the package as delivered.

## What is verified, and what is not

- **Compile-only.** Live compile into scratch Snowflake databases with 0 errors: bare-bones
  360/360, publish_dest S10 45/45, deactivate/reactivate 17/17. See `snowflake/COMPILE_REPORT_*.md`.
- **Not validated:** runtime behaviour, and row-count parity against the IDQ results.
- **NULL columns:** the S10 twins carry NULL where the first step does not provide a column,
  147 of 963 columns in total (mostly TRS and CRE). They are listed in the `*_S10_MAP.md` files.
- **Not linked yet:** tx-mdm does not yet know which IDMC CDI task loads which C_S_* table. The
  CDI task list comes from the org at runtime. Any mapping from task to table would come from
  Vamsi or from the task metadata, not from this package.

## Open items in the package — parked

The idq-cli work has open items that Vamsi parked on 2026-11-22. **Do not raise or try to
resolve them from this repo.** Wait until he brings them up. They live with the idq-cli work,
not here.
