-- ============================================================================
-- sp_snow_step_CRE_CARE_S30_RANKED  --  BARE-BONES STEP (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing, step 30.
-- Produces WRK_CRE_CARE_S3_RANKED; consumes WRK_CRE_CARE_S2_NAMED.
-- Original parameters used: none.
--
-- Bare-bones variant: no P_JOB_RUN_ID, no P_INPUT_TABLES, no
-- existence check, no checkpoint call. The CTAS below is the
-- v2.1 step SELECT verbatim; only the dropped parameters and
-- framework blocks were removed. No exception block (errors
-- propagate to the driver handler), no transaction, no target write.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_CRE_CARE_S30_RANKED (
    P_RUN_TS       TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: RANK_ENRICH (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_CRE_CARE_S3_RANKED AS
    WITH
    lkp_exc  AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    lkp_any  AS (SELECT * FROM TABLE(fn_snow_helper42_common())),
    lkp_cv   AS (SELECT * FROM TABLE(fn_snow_helper41_common())),
    lkp_area AS (SELECT * FROM TABLE(fn_snow_helper44_common())),
    -- SRT_VALID_MEMBERS + EXP_VALID_MEMBERS2 + LKP_INVALID_FIRSTNM / LASTNM + LKP_STATE_CODE
    ranked AS (
        SELECT m.*,
               /* TIMELINE: VERSION_SEQ_NUM per CARE id, REC_TYPE descending */
               IFF(m.valid_member,
                   ROW_NUMBER() OVER (PARTITION BY m.valid_member, m.CARE_ID ORDER BY m.REC_TYPE DESC), NULL)
                                                                                       AS version_seq_num,
               xf.EXCEPTION_CODE AS fn_exception_code, xf.EXCEPTION_DESC AS fn_exception_desc,
               xf.EXCEPTION_TYPE AS fn_exception_type,
               xl.EXCEPTION_CODE AS ln_exception_code, xl.EXCEPTION_DESC AS ln_exception_desc,
               xl.EXCEPTION_TYPE AS ln_exception_type,
               IFF(m.orig_rowid_object_desc = 'N', m.TARGET_ID, m.CARE_ID)             AS mrg_care_id,
               /* BAD DATA: SSN_OUT suppresses the default values */
               IFF(m.SSN = 'U' OR m.SSN = 'N', NULL, m.SSN)                            AS ssn_out,
               st.MSTR_CODE_VALUE                                                      AS std_state_cd
          FROM WRK_CRE_CARE_S2_NAMED m
          LEFT JOIN lkp_exc xf ON xf.EXCEPTION_CODE = m.fn_missing_code
          LEFT JOIN lkp_exc xl ON xl.EXCEPTION_CODE = m.ln_missing_code
          LEFT JOIN lkp_any st ON st.SRC_SYS = 'CRE' AND st.SRC_CODE_VALUE = m.STATE
    ),
    -- the mapplets and rules (only the de-duplicated members are routed to a target)
    dq AS (
        SELECT r.*,
               NVL(r.version_seq_num = 1, FALSE)                                       AS is_member,
               fn_snow_helper17_common(r.SEX, 'Indv', 'CRE')                           AS gd,
               et.MSTR_CODE_VALUE                                                      AS ethnicity_mstr,
               rc.MSTR_CODE_VALUE                                                      AS race_mstr,
               fn_snow_helper23_common(r.PHONE)                                        AS phone_std,
               fn_snow_helper37_common(r.mrg_care_id)                                  AS ci,
               fn_snow_helper27_common(r.RECIP_NO)                                     AS md,
               fn_snow_helper26_common(r.ssn_out)                                      AS sn,
               /* RTR_US_ADDRESSES.US_ADDRESSES: STD_STATE_CD <> '99' OR ISNULL(STD_STATE_CD) */
               NVL(r.std_state_cd <> '99', TRUE)                                       AS addr_us,
               ss.MSTR_CODE_VALUE                                                      AS source_state_fips
          FROM ranked r
          LEFT JOIN lkp_cv et ON et.CODE_TYPE = 'ETHNICITY' AND et.SRC_SYS = 'CRE' AND et.SRC_CODE_VALUE = r.FEDETH
          LEFT JOIN lkp_cv rc ON rc.CODE_TYPE = 'RACE' AND rc.SRC_SYS = 'CRE' AND rc.SRC_CODE_VALUE = r.RACE
          LEFT JOIN lkp_cv ss ON ss.CODE_TYPE = 'STATE' AND ss.SRC_SYS = 'CRE'
                             AND ss.SRC_CODE_VALUE = UPPER(TRIM(r.STATE))
    )
    -- mplt_Global_Addr_Validation (US addresses) + rule_Phone_Std exception code
    SELECT d.*,
           IFF(d.addr_us, fn_snow_helper34_common(d.STREET, NULL, d.CITY, d.STATE,
                                                  NVL(d.ZIP, '') || '-' || NVL(d.ZIPSUF, ''), 'US',
                                                  d.source_state_fips), NULL) AS av,
           /* VALIDATION */
           fn_snow_helper24_common(d.phone_std, NULL, NULL, ar.NPA_ID, ar.SERVICE)  AS phone_code
      FROM dq d
      LEFT JOIN lkp_area ar ON ar.NPA_ID = SUBSTR(d.phone_std, 1, 3);
    SELECT COUNT(*) INTO :l_rows FROM WRK_CRE_CARE_S3_RANKED;
    RETURN :l_rows;
END;
$$;
