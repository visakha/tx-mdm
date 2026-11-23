-- ============================================================================
-- sp_snow_step_WIC_ADR_S40_SCORED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Addr, workflow wf_WIC_Stage_Load.
-- Step 40: SCORED.
-- Produces: WRK_WIC_ADDR_S40_SCORED -- Score (100 or 40), exception detail, held address lines, run constants, and the insert-only guards (uq_addr, uq_addr_exc). Target guard evaluated here, before publish, as in the original single query.
-- Consumes: WRK_WIC_ADDR_S30_FLAT
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_ADR_S40_SCORED (
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD VARCHAR DEFAULT 'Member Addr',
    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows NUMBER DEFAULT 0;
BEGIN
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_ADDR_S40_SCORED AS
    WITH
    scored AS (
        SELECT f.*,
               /* VALIDATION */ fn_snow_helper05_common('002', f.a_mailability_score, f.a_match_code) AS score,
               fn_snow_helper06_common('002', f.a_mailability_score, f.a_match_code)   AS addr_issue_desc,
               fn_snow_helper07_common(f.a_line1, f.a_line2)                          AS hold_line1,
               fn_snow_helper08_common(f.a_line1, f.a_line2)                          AS hold_line2
          FROM WRK_WIC_ADDR_S30_FLAT f
    )
    SELECT s.*,
           '002'                                                         AS addr_tp,
           'US'                                                          AS src_cntry,
           'WIC'                                                         AS src_sys,
           :P_RUN_TS                                                     AS run_ts,
           :c_mapping                                                    AS mapping_name,
           1 /* TIMELINE: VERSION_SEQ */                                 AS version_seq,
           1                                                             AS hub_state_ind,
           NVL(s.PTY_SRC_KEY, '') || '|Member'                           AS pty_rle_fk,
           LPAD(TO_VARCHAR(s.ID), 10, '0')                               AS dqm_pty_src_key,
           'Primary'                                                     AS pref_lvl,
           NVL(TO_VARCHAR(s.ID), '') || '|' || NVL(TO_VARCHAR(s.FID), '') AS loc_idn,
           :P_MEMBER_HIERARCHY_CODE                                      AS hierarchy_code,
           :P_MEMBER_HM_REL_TP_CD                                        AS hm_rel_tp_cd,
           IFF(s.addr_issue_desc IS NOT NULL, 'Address', NULL)           AS exc_attribute_name,
           IFF(s.addr_issue_desc IS NOT NULL,
               NVL(s.ADDRESS1, '') || ' ' || NVL(s.ADDRESS2, '') || ' ' || NVL(s.CITY, '') || '  '
               || NVL(s.ZIP_CODE, '') || '  US', NULL)                   AS exc_attribute_value,
           'Invalid_Address'                                             AS exc_code,
           'Invalid Address per Address Doctor'                          AS exc_desc,
           'Bad Value'                                                   AS exc_type,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY s.score, s.pkey_src_object
                                   ORDER BY s.DATE_ADDRESS_VALID_FROM DESC, s.FID) = 1
            AND xa.PKEY_SRC_OBJECT IS NULL)                              AS uq_addr,
           ROW_NUMBER() OVER (PARTITION BY s.score, s.ID, s.FID, s.SOURCE_TABLE
                                  ORDER BY s.DATE_ADDRESS_VALID_FROM DESC) = 1 AS uq_addr_exc
      FROM scored s
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = s.pkey_src_object;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_ADDR_S40_SCORED;
    RETURN :l_rows;
END;
$$;
