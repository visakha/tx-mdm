# ECI PUBLISH_REACTIVATE S10-only map

S10-only twins: ONLY the first (source) step is inlined as a CTE;
later steps and the WHERE gate are dropped. Each target column is
aliased from a first-step column, a literal, or a parameter. A
column the first step does not carry is NULL (recorded below).
A literal producer anywhere in the chain is kept (e.g. the
action label 'Deactivation' / 'Reactivation' from the routing
step); the gate that selects which rows get it is still dropped.

Built: 4 twins. Failed: 0.

## Twins

### sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS.sql -> STG_ECI_D_FAMILY_ADDRESS

- Kept steps: `s10_latest`. P_RUN_TS: NO.
- WHERE gate dropped: `none`.
- Column map:
  - `ID_FAMILY_ADDRESS` <- `ID_FAMILY_ADDRESS` (via s20_keepnew; was `h.ID_FAMILY_ADDRESS`)
  - `ID_FAMILY` <- `ID_FAMILY` (via s20_keepnew; was `h.ID_FAMILY`)
  - `ID_CASE` <- `ID_CASE` (via s20_keepnew; was `h.ID_CASE`)
  - `ADDRESS_CD` <- `ADDRESS_CD` (via s20_keepnew; was `h.ADDRESS_CD`)
  - `ADDRESS1` <- `ADDRESS1` (via s20_keepnew; was `h.ADDRESS1`)
  - `ADDRESS2` <- `ADDRESS2` (via s20_keepnew; was `h.ADDRESS2`)
  - `ID_ST_CITY_CNTY_ZIP` <- `ID_ST_CITY_CNTY_ZIP` (via s20_keepnew; was `h.ID_ST_CITY_CNTY_ZIP`)
  - `CITY_NAME` <- `CITY_NAME` (via s20_keepnew; was `h.CITY_NAME`)
  - `COUNTY_NAME` <- `COUNTY_NAME` (via s20_keepnew; was `h.COUNTY_NAME`)
  - `ZIP_CODE` <- `ZIP_CODE` (via s20_keepnew; was `h.ZIP_CODE`)
  - `ZIP_SFX` <- `ZIP_SFX` (via s20_keepnew; was `h.ZIP_SFX`)
  - `STATE_ABBREV` <- `STATE_ABBREV` (via s20_keepnew; was `h.STATE_ABBREV`)
  - `CANCEL_DATE` <- `CANCEL_DATE` (via s20_keepnew; was `h.CANCEL_DATE`)
  - `DATE_CREATED` <- `DATE_CREATED` (via s20_keepnew; was `h.DATE_CREATED`)
  - `DATE_MODIFIED` <- `DATE_MODIFIED` (via s20_keepnew; was `h.DATE_MODIFIED`)
  - `MODIFIED_BY` <- `MODIFIED_BY` (via s20_keepnew; was `h.MODIFIED_BY`)
  - `CREATED_BY` <- `CREATED_BY` (via s20_keepnew; was `h.CREATED_BY`)
  - `LOAD_DATE` <- `LOAD_DATE` (via s20_keepnew; was `h.LOAD_DATE`)

### sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID.sql -> STG_ECI_D_MEDICAID

- Kept steps: `s10_latest`. P_RUN_TS: NO.
- WHERE gate dropped: `none`.
- Column map:
  - `ID_MEDICAID` <- `ID_MEDICAID` (via s20_keepnew; was `h.ID_MEDICAID`)
  - `ID_CASE` <- `ID_CASE` (via s20_keepnew; was `h.ID_CASE`)
  - `MEDICAID_NBR` <- `MEDICAID_NBR` (via s20_keepnew; was `h.MEDICAID_NBR`)
  - `ELIG_DATE` <- `ELIG_DATE` (via s20_keepnew; was `h.ELIG_DATE`)
  - `END_DATE` <- `END_DATE` (via s20_keepnew; was `h.END_DATE`)
  - `CURRENT_IND` <- `CURRENT_IND` (via s20_keepnew; was `h.CURRENT_IND`)
  - `CANCEL_DATE` <- `CANCEL_DATE` (via s20_keepnew; was `h.CANCEL_DATE`)
  - `HMO_DESC` <- `HMO_DESC` (via s20_keepnew; was `h.HMO_DESC`)
  - `DATE_CREATED` <- `DATE_CREATED` (via s20_keepnew; was `h.DATE_CREATED`)
  - `DATE_MODIFIED` <- `DATE_MODIFIED` (via s20_keepnew; was `h.DATE_MODIFIED`)
  - `MODIFIED_BY` <- `MODIFIED_BY` (via s20_keepnew; was `h.MODIFIED_BY`)
  - `CREATED_BY` <- `CREATED_BY` (via s20_keepnew; was `h.CREATED_BY`)
  - `CONSENT_TO_BILL` <- `CONSENT_TO_BILL` (via s20_keepnew; was `h.CONSENT_TO_BILL`)
  - `LOAD_DATE` <- `LOAD_DATE` (via s20_keepnew; was `h.LOAD_DATE`)

### sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE.sql -> STG_ECI_D_FAMILY_PHONE

- Kept steps: `s10_latest`. P_RUN_TS: NO.
- WHERE gate dropped: `none`.
- Column map:
  - `ID_FAMILY_PHONE` <- `ID_FAMILY_PHONE` (via s20_keepnew; was `h.ID_FAMILY_PHONE`)
  - `ID_FAMILY` <- `ID_FAMILY` (via s20_keepnew; was `h.ID_FAMILY`)
  - `ID_CASE` <- `ID_CASE` (via s20_keepnew; was `h.ID_CASE`)
  - `HOME_AC` <- `HOME_AC` (via s20_keepnew; was `h.HOME_AC`)
  - `HOME_NBR` <- `HOME_NBR` (via s20_keepnew; was `h.HOME_NBR`)
  - `WORK_AC` <- `WORK_AC` (via s20_keepnew; was `h.WORK_AC`)
  - `WORK_NBR` <- `WORK_NBR` (via s20_keepnew; was `h.WORK_NBR`)
  - `WORK_EXT` <- `WORK_EXT` (via s20_keepnew; was `h.WORK_EXT`)
  - `CELL_AC` <- `CELL_AC` (via s20_keepnew; was `h.CELL_AC`)
  - `CELL_NBR` <- `CELL_NBR` (via s20_keepnew; was `h.CELL_NBR`)
  - `FAX_AC` <- `FAX_AC` (via s20_keepnew; was `h.FAX_AC`)
  - `FAX_NBR` <- `FAX_NBR` (via s20_keepnew; was `h.FAX_NBR`)
  - `PAGER_AC` <- `PAGER_AC` (via s20_keepnew; was `h.PAGER_AC`)
  - `PAGER_NBR` <- `PAGER_NBR` (via s20_keepnew; was `h.PAGER_NBR`)
  - `OTHER_AC` <- `OTHER_AC` (via s20_keepnew; was `h.OTHER_AC`)
  - `OTHER_NBR` <- `OTHER_NBR` (via s20_keepnew; was `h.OTHER_NBR`)
  - `EMAIL_ADDRESS` <- `EMAIL_ADDRESS` (via s20_keepnew; was `h.EMAIL_ADDRESS`)
  - `DATE_CREATED` <- `DATE_CREATED` (via s20_keepnew; was `h.DATE_CREATED`)
  - `DATE_MODIFIED` <- `DATE_MODIFIED` (via s20_keepnew; was `h.DATE_MODIFIED`)
  - `MODIFIED_BY` <- `MODIFIED_BY` (via s20_keepnew; was `h.MODIFIED_BY`)
  - `CREATED_BY` <- `CREATED_BY` (via s20_keepnew; was `h.CREATED_BY`)
  - `CHILD_RESIDES_IND` <- `CHILD_RESIDES_IND` (via s20_keepnew; was `h.CHILD_RESIDES_IND`)
  - `INACTIVE_IND` <- `INACTIVE_IND` (via s20_keepnew; was `h.INACTIVE_IND`)
  - `PRIMARY_CONTACT_IND` <- `PRIMARY_CONTACT_IND` (via s20_keepnew; was `h.PRIMARY_CONTACT_IND`)
  - `LOAD_DATE` <- `LOAD_DATE` (via s20_keepnew; was `h.LOAD_DATE`)

### sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION.sql -> STG_ECI_PTY_INACTIVE_LOG

- Kept steps: `s10_src`. P_RUN_TS: YES.
- WHERE gate dropped: `WHERE grp_reactivation`.
- Column map:
  - `SRC_KEY` <- `PKEY_SRC_OBJECT` (via s30_routed; was `pkey_src_object`)
  - `ROWID_SYSTEM` <- `SRC_SYSTEM` (via s30_routed; was `src_system`)
  - `ACTION` <- `'Reactivation'` (via s30_routed; was `action_reactivation`)
  - `ACTION_DT` <- `:P_RUN_TS` (via s30_routed; was `run_ts`)

