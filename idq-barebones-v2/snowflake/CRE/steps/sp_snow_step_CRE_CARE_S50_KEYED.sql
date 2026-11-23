-- ============================================================================
-- sp_snow_step_CRE_CARE_S50_KEYED  --  BARE-BONES STEP (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing, step 50.
-- Produces WRK_CRE_CARE_S5_KEYED; consumes WRK_CRE_CARE_S4_FLAT.
-- Original parameters used: P_PHYSICAL_ADDR_TYPE_CD, P_RLE_BO_CLASS_CD_MEMBER, P_DEFAULT_TX_STATE_CD, P_COUNTY_CD_NONTX, P_COUNTYCD_DEFAULTALL.
--
-- Bare-bones variant: no P_JOB_RUN_ID, no P_INPUT_TABLES, no
-- existence check, no checkpoint call. The CTAS below is the
-- v2.1 step SELECT verbatim; only the dropped parameters and
-- framework blocks were removed. No exception block (errors
-- propagate to the driver handler), no transaction, no target write.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_CRE_CARE_S50_KEYED (
    P_PHYSICAL_ADDR_TYPE_CD      VARCHAR DEFAULT '002',
    P_RLE_BO_CLASS_CD_MEMBER     VARCHAR DEFAULT 'Member',
    P_DEFAULT_TX_STATE_CD        VARCHAR DEFAULT '48',
    P_COUNTY_CD_NONTX            VARCHAR DEFAULT '996',
    P_COUNTYCD_DEFAULTALL        VARCHAR DEFAULT '998',
    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 50: KEYED_ROUTES_GUARDS (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_CRE_CARE_S5_KEYED AS
    WITH
    keyed AS (
        SELECT f.*,
               /* EXP_PTY_RLE_ADDR_HOLD.out_COUNTY_CD */
               CASE WHEN f.a_state <> :P_DEFAULT_TX_STATE_CD THEN :P_COUNTY_CD_NONTX
                    WHEN f.a_county_fips IS NULL THEN :P_COUNTYCD_DEFAULTALL
                    ELSE f.a_county_fips END                                           AS a_county,
               f.rle_key || '|' || :P_PHYSICAL_ADDR_TYPE_CD                            AS addr_key,
               IFF(f.care_alt_id IN ('U', 'N'), NULL, f.care_alt_id)                   AS care_alt_val,
               IFF(f.medicaid_alt_id IN ('U', 'N'), NULL, f.medicaid_alt_id)           AS medicaid_alt_val,
               f.rle_key || '|' || NVL(f.care_tp_cd, '') || '|' || NVL(f.care_alt_id, '')         AS care_alt_key,
               f.rle_key || '|' || NVL(f.medicaid_tp_cd, '') || '|' || NVL(f.medicaid_alt_id, '') AS medicaid_alt_key,
               f.rle_key || '|' || NVL(f.ssn_tp_cd, '') || '|' || NVL(f.ssn_out, '')              AS ssn_alt_key,
               /* routes (every flag NVL'd: a NULL router condition does not route) */
               NOT f.grp_deletes AND NVL(f.orig_rowid_object_desc = 'N', FALSE)        AS grp_mrg,
               NOT f.valid_member AND (f.fn_exception_code IS NOT NULL OR f.fn_exception_desc IS NOT NULL
                                       OR f.fn_exception_type IS NOT NULL)            AS grp_first_name,
               NOT f.valid_member AND (f.ln_exception_code IS NOT NULL OR f.ln_exception_desc IS NOT NULL
                                       OR f.ln_exception_type IS NOT NULL)            AS grp_last_name,
               f.is_member AND f.gender_exception_description IS NOT NULL              AS grp_gender,
               f.is_member AND f.suffix_exception_code IS NOT NULL                     AS grp_suffix,
               f.is_member AND f.ethnicity_exception_code IS NOT NULL                  AS grp_ethnicity,
               f.is_member AND f.race_exception_code IS NOT NULL                       AS grp_race,
               f.is_member AND f.addr_valid                                            AS grp_addr,
               f.is_member AND NOT f.addr_valid                                        AS grp_addr_exc,
               f.is_member AND f.PHONE IS NOT NULL AND f.phone_exception_code IS NULL  AS grp_phone,
               f.is_member AND f.PHONE IS NOT NULL AND f.phone_exception_code IS NOT NULL AS grp_phone_exc,
               f.is_member AND f.care_alt_id IS NOT NULL                               AS grp_care_alt,
               f.is_member AND f.medicaid_alt_id IS NOT NULL AND f.medicaid_exception_code IS NULL
                                                                                       AS grp_medicaid_alt,
               f.is_member AND f.medicaid_alt_id IS NOT NULL AND f.medicaid_exception_code IS NOT NULL
                                                                                       AS grp_medicaid_exc,
               f.is_member AND f.ssn_out IS NOT NULL AND f.ssn_exception_code IS NULL  AS grp_ssn_alt,
               f.is_member AND f.ssn_out IS NOT NULL AND f.ssn_exception_code IS NOT NULL AS grp_ssn_exc
          FROM WRK_CRE_CARE_S4_FLAT f
    )
    SELECT k.*,
           'CRE'                                             AS src_sys,
           :P_RUN_TS                                         AS run_ts,
           :c_mapping                                        AS mapping_name,
           'Indv'                                            AS pty_bo_class_cd,
           :P_RLE_BO_CLASS_CD_MEMBER                         AS rle_bo_class_cd,
           :P_PHYSICAL_ADDR_TYPE_CD                          AS addr_tp,
           'Payer'                                           AS hierarchy_code,
           'Primary'                                         AS pref_lvl,
           'Member Addr'                                     AS hm_rel_tp_cd,
           'US'                                              AS src_cntry,
           'Telephone'                                       AS phn_tp,
           '001'                                             AS usg_tp_phone,
           'Issued'                                          AS sts_cd,
           'First Name'                                      AS attr_first_name,
           'Last Name'                                       AS attr_last_name,
           'Gender'                                          AS attr_gender,
           'Name Suffix'                                     AS attr_suffix,
           'FEDETH'                                          AS attr_fedeth,
           'RACE'                                            AS attr_race,
           'Address'                                         AS attr_address,
           'Telephone'                                       AS attr_phone,
           CAST(NULL AS TIMESTAMP_NTZ)                       AS null_timestamp,   -- TIMELINE: not linked
           CAST(NULL AS NUMBER)                              AS null_number,      -- TIMELINE: not linked
           /* BAD DATA: SRC_ROWID is 30 characters */
           LEFT(k.addr_key, 30)                              AS addr_src_rowid,
           LEFT(k.phn_key, 30)                               AS phn_src_rowid,
           LEFT(k.care_alt_key, 30)                          AS care_alt_src_rowid,
           LEFT(k.medicaid_alt_key, 30)                      AS medicaid_alt_src_rowid,
           LEFT(k.ssn_alt_key, 30)                           AS ssn_alt_src_rowid,
           /* BAD DATA: unique keys Snowflake does not enforce */
           ROW_NUMBER() OVER (PARTITION BY k.grp_first_name, k.CARE_ID, k.fn_exception_type, k.fn_exception_code
                              ORDER BY k.REC_TYPE DESC) = 1  AS uq_first_name,
           ROW_NUMBER() OVER (PARTITION BY k.grp_last_name, k.CARE_ID, k.ln_exception_type, k.ln_exception_code
                              ORDER BY k.REC_TYPE DESC) = 1  AS uq_last_name,
           xpty.PKEY_SRC_OBJECT IS NULL                      AS uq_pty,
           xrle.PKEY_SRC_OBJECT IS NULL                      AS uq_rle,
           xadr.PKEY_SRC_OBJECT IS NULL                      AS uq_addr,
           xphn.PKEY_SRC_OBJECT IS NULL                      AS uq_phone,
           xca.PKEY_SRC_OBJECT IS NULL                       AS uq_care_alt,
           xma.PKEY_SRC_OBJECT IS NULL                       AS uq_medicaid_alt,
           xsa.PKEY_SRC_OBJECT IS NULL                       AS uq_ssn_alt,
           ROW_NUMBER() OVER (PARTITION BY k.grp_medicaid_exc, k.mrg_care_id, k.medicaid_exception_type,
                                           k.medicaid_exception_code ORDER BY k.REC_TYPE DESC) = 1
                                                             AS uq_medicaid_exc,
           ROW_NUMBER() OVER (PARTITION BY k.grp_ssn_exc, k.mrg_care_id, k.ssn_exception_type,
                                           k.ssn_exception_code ORDER BY k.REC_TYPE DESC) = 1
                                                             AS uq_ssn_exc
      FROM keyed k
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY WHERE VERSION_SEQ = 1) xpty
             ON xpty.PKEY_SRC_OBJECT = k.pty_key
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE WHERE VERSION_SEQ = 1) xrle
             ON xrle.PKEY_SRC_OBJECT = k.rle_key
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xadr
             ON xadr.PKEY_SRC_OBJECT = k.addr_key
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xphn
             ON xphn.PKEY_SRC_OBJECT = k.phn_key
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xca
             ON xca.PKEY_SRC_OBJECT = k.care_alt_key
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xma
             ON xma.PKEY_SRC_OBJECT = k.medicaid_alt_key
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_CRE_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xsa
             ON xsa.PKEY_SRC_OBJECT = k.ssn_alt_key;
    SELECT COUNT(*) INTO :l_rows FROM WRK_CRE_CARE_S5_KEYED;
    RETURN :l_rows;
END;
$$;
