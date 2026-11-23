# idq-barebones-v2 - imported reference copy

Imported from **github.com/visakha/idq-cli**, folder `barebones-v2/`,
at commit **`adde845cf971701976bd5045670a6581281b1852`** (2026-11-19,
"Add Business Requirements column to PKEY lineage sheet"). Imported 2026-11-22.

This is the Informatica IDQ -> Snowflake bare-bones rebuild for the MDM load
(sources ECI, FSS, TTF, WIC, TRS, CRE). The CDI jobs that tx-mdm runs read and write
these same tables. The two projects stay separate on purpose. **This folder is a
read-only snapshot.** Make changes in idq-cli and re-import them; do not edit them here.

## What is here

| Path | What it is | Source in idq-cli |
|---|---|---|
| `snowflake/` | The full contents of `Snowflake_All_Sources_Bare_Bones_v2.1_COMPILED_PUBLISH_DEST_S10_DEACT_REACT.zip`, unzipped (472 entries). This is the latest package and a superset of the S10 zip: `00_common/` helpers, plus `drivers/ steps/ publish/ publish_dest/ publish_deactivate/ publish_reactivate/ manifests/ runners/` for each source, and the package docs (`README.md`, `STEP_MAP.md`, `DEPENDENCIES.md`, `STRIPPED_NOTES.md`, `PUBLISH_DEST_S10_NOTES.md`, `PUBLISH_DEACT_REACT_NOTES.md`, `COMPILE_REPORT_*.md`) | `barebones-v2/..._DEACT_REACT.zip` (commit cc9c97e) |
| `sheets/PKEY_SRC_OBJECT_Formulation.xlsx` | How each of the 45 C_S_* targets forms its PKEY_SRC_OBJECT, per source | commit 7033e5d |
| `sheets/PKEY_SRC_OBJECT_Lineage.xlsx` | PKEY lineage traced to the staging origins, with 114 rows and a Business Requirements column | commit adde845 |
| `deck/Init_SQL_Three_Source_Pattern.pptx` | Team deck: "The Init SQL - three sources, one pattern" | commit 39da89b |

## Not copied (see the source repo)

These are earlier package zips. The unzipped `snowflake/` folder above supersedes them,
and they are still in idq-cli at the same commit:

- `Snowflake_All_Sources_Bare_Bones_v2.1.zip` (427 entries, uncompiled v2.1, commit 39e9741)
- `Snowflake_All_Sources_Bare_Bones_v2.1_COMPILED.zip` (391 entries, commit 39e9741)
- `Snowflake_All_Sources_Bare_Bones_v2.1_COMPILED_PUBLISH_DEST_S10.zip` (444 entries, commit d5217c0)

## Verification status (as recorded in the package's own compile reports)

- **Compile-only.** Every SQL file was compiled live into scratch Snowflake databases with 0 errors:
  - bare-bones: 360/360
  - publish_dest S10: 45/45
  - deactivate/reactivate: 17/17
- **Not validated:** runtime behaviour, and row-count parity against the IDQ results.
- Where a column is NULL in the S10 twins, it is because that step does not carry the value. The
  `*_S10_MAP.md` files and `PUBLISH_DEST_S10_NOTES.md` list these.
