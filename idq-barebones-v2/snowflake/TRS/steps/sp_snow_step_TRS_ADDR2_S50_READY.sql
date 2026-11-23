-- ============================================================================
-- sp_snow_step_TRS_ADDR2_S50_READY  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Addr_2, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: READY_TO_PUBLISH. Produces: WRK_TRS_ADDR2_S50_READY.
-- Consumes (v2.1 declared inputs): WRK_TRS_ADDR2_S40_SCORED.
-- Original params used: P_MEMBER_ROLE_TYPE, P_MEMBER_HIERARCHY_CODE, P_MEMBER_HM_REL_TP_CD; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ADDR2_S50_READY (

    P_MEMBER_ROLE_TYPE VARCHAR DEFAULT 'Member',
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
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Addr_2';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 50: READY_TO_PUBLISH (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ADDR2_S50_READY AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT c.*,
           'TRS'                                                                AS src_sys,
           :P_RUN_TS                                                            AS run_ts,
           :c_mapping                                                           AS mapping_name,
           :P_MEMBER_HIERARCHY_CODE                                             AS hierarchy_code,
           :P_MEMBER_HM_REL_TP_CD                                               AS hm_rel_tp_cd,
           'Primary'                                                            AS pref_lvl,
           IFF(c.EFF_END_DT IS NOT NULL, :P_RUN_TS, NULL)                        AS period_reference_time,
           c.pkey_pty_rle_addr || '|' || TO_VARCHAR(c.version_seq)               AS src_rowid,
           NVL(TO_VARCHAR(TRUNC(c.CASE_NUM)), '') || '|' || NVL(TO_VARCHAR(TRUNC(c.EDG_NUM)), '') AS loc_idn,
           NVL(c.PTY_PK, '') || '|' || :P_MEMBER_ROLE_TYPE                      AS pty_rle_fk,
           fn_snow_helper07_common(c.ADDR_LN_1, c.ADDR_LN_2)                    AS hold_line1,
           fn_snow_helper08_common(c.ADDR_LN_1, c.ADDR_LN_2)                    AS hold_line2,
           NVL(c.ADDR_LN_1, '') || '|' || NVL(c.ADDR_LN_2, '') || '|' || NVL(c.CITY, '') || '|' || c.rslt_pstl_cd
           || '|' || NVL(c.STATE, '') || '|' || NVL(c.CNTRY_CD, '')             AS dqm_addr_src_key,
           NVL(c.SRC_PSTL_CD, '') || IFF(c.SRC_PSTL_CD_EXT IS NOT NULL, '-' || c.SRC_PSTL_CD_EXT, '') AS dqm_src_pstl_cd,
           IFF(c.addr_issue_desc IS NOT NULL, 'Address', NULL)                  AS exc_attribute_name,
           IFF(c.addr_issue_desc IS NOT NULL,
               NVL(c.SRC_ADDR_LN_1, '') || ' ' || NVL(c.SRC_ADDR_LN_2, '') || ' ' || NVL(c.SRC_CITY, '') || ' '
               || NVL(c.SRC_STATE, '') || ' ' || NVL(TO_VARCHAR(c.SRC_PSTL_CD), '') || ' '
               || NVL(TO_VARCHAR(c.SRC_PSTL_CD_EXT), '') || ' ' || NVL(c.SRC_CNTRY, ''), NULL) AS exc_attribute_value,
           ex.EXCEPTION_CODE                                                    AS exc_code,
           ex.EXCEPTION_DESC                                                    AS exc_desc,
           ex.EXCEPTION_TYPE                                                    AS exc_type,
           xa.PKEY_SRC_OBJECT IS NULL                                           AS uq_addr,
           ROW_NUMBER() OVER (PARTITION BY c.score, c.INDV_ID, c.CASE_NUM, c.EDG_NUM
                                  ORDER BY c.CREATE_DT DESC, c.ADDR_TYPE_CD) = 1 AS uq_addr_exc
      FROM WRK_TRS_ADDR2_S40_SCORED c
      LEFT JOIN lkp_exc ex ON ex.EXCEPTION_CODE = 'Invalid_Address'
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_ADDR) xa
             ON xa.PKEY_SRC_OBJECT = c.pkey_pty_rle_addr AND xa.VERSION_SEQ = c.version_seq;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ADDR2_S50_READY;
    RETURN :l_rows;
END;$$;
