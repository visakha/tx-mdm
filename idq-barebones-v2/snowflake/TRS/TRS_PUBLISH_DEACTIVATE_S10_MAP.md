# TRS PUBLISH_DEACTIVATE S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).
A literal producer anywhere in the chain is kept (e.g. the
action label 'Deactivation' / 'Reactivation' from the routing
step); the gate that selects which rows get it is still dropped.

Built: 2 twins. Failed: 0.

## Twins

### sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS.sql -> STG_TRS_DEACTIVED_MEMBERS

- Kept steps: `s10_deactv`. P_RUN_TS: YES.
- WHERE gate dropped: `none`.
- Columns set to NULL (no first-step source): INDV_ID (via s30_ready), PTY_PK (via s30_ready), SRC_TBL (via s30_ready), CREATE_DATE (via s30_ready).
- Column map:
  - `INDV_ID` <- `NULL` (via s30_ready; was `INDV_ID`)
  - `PTY_PK` <- `NULL` (via s30_ready; was `PTY_PK`)
  - `SRC_TBL` <- `NULL` (via s30_ready; was `SRC_TBL`)
  - `CREATE_DATE` <- `NULL` (via s30_ready; was `CREATE_DATE`)
  - `SRC_DEACTIVATION_DATE` <- `CREATE_DT` (via s30_ready; was `SRC_DEACTIVATION_DATE`)
  - `LOAD_DATE` <- `:P_RUN_TS` (via s30_ready; was `LOAD_DATE`)
  - `INACTIVE_IND` <- `INACTIVE_IND` (via s30_ready; was `INACTIVE_IND`)
  - `DELETE_SW` <- `DELETE_SW` (via s30_ready; was `DELETE_SW`)
  - `PROCESSED_YN` <- `' '` (via s30_ready; was `PROCESSED_YN`)

### sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS.sql -> STG_TRS_DEACTIVATED_RELATIONSHIPS

- Kept steps: `s10_minpk`. P_RUN_TS: YES.
- WHERE gate dropped: `none`.
- Columns set to NULL (no first-step source): INDV_ID (via s50_ready), REF_INDV_ID (via s50_ready), REL_TYPE_CODE (via s50_ready), SRC_PKEY_CT (via s50_ready), PKEY_SRC_OBJECT (via s50_ready), ROWID_OBJECT (via s50_ready), MASTER_RECORD_YN (via s50_ready), MERGED_YN (via s50_ready), ROWID_XREF (trace too deep for ROWID_XREF).
- Column map:
  - `INDV_ID` <- `NULL` (via s50_ready; was `INDV_ID`)
  - `REF_INDV_ID` <- `NULL` (via s50_ready; was `REF_INDV_ID`)
  - `PTY_RLE_FK_1` <- `IFF(PTY_PK IS NULL, NULL, TRIM(PTY_PK) || '       ')` (via s50_ready; was `PTY_RLE_FK_1`)
  - `PTY_RLE_FK_2` <- `IFF(PTY_PK IS NULL, NULL, TRIM(PTY_PK) || '       ')` (via s50_ready; was `PTY_RLE_FK_2`)
  - `REL_TYPE_CODE` <- `NULL` (via s50_ready; was `REL_TYPE_CODE`)
  - `SRC_PKEY_CT` <- `NULL` (via s50_ready; was `SRC_PKEY_CT`)
  - `LOAD_DATE` <- `:P_RUN_TS` (via s50_ready; was `LOAD_DATE`)
  - `PKEY_SRC_OBJECT` <- `NULL` (via s50_ready; was `PKEY_SRC_OBJECT`)
  - `ROWID_OBJECT` <- `NULL` (via s50_ready; was `ROWID_OBJECT`)
  - `MASTER_RECORD_YN` <- `NULL` (via s50_ready; was `MASTER_RECORD_YN`)
  - `MERGED_YN` <- `NULL` (via s50_ready; was `MERGED_YN`)
  - `ROWID_SYSTEM` <- `'   '` (via s50_ready; was `ROWID_SYSTEM`)
  - `ROWID_XREF` <- `NULL` (trace too deep for ROWID_XREF; was `ROWID_XREF`)

