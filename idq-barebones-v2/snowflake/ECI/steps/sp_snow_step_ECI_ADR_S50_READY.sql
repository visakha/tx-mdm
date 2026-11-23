-- sp_snow_step_ECI_ADR_S50_READY -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Addr, workflow wf_ECI_Stage_Load, step 50 (SCORED_READY).
-- Produces: WRK_ECI_ADR_S50_READY.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_ADR_S50_READY (
    P_MEMBER_HIERARCHY_CODE VARCHAR DEFAULT 'Member',
    P_MEMBER_HM_REL_TP_CD VARCHAR DEFAULT 'Member Addr',
    P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Addr';
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 50: SCORED_READY (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_ADR_S50_READY AS
    WITH
    scored AS (
        SELECT f.*,
               fn_snow_helper05_common(f.mstr_addr_tp, f.a_mailability_score, f.a_match_code) AS score,
               fn_snow_helper06_common(f.mstr_addr_tp, f.a_mailability_score, f.a_match_code)   AS addr_issue_desc,
               fn_snow_helper07_common(f.a_line1, f.a_line2)                                   AS hold_line1,
               fn_snow_helper08_common(f.a_line1, f.a_line2)                                   AS hold_line2
          FROM WRK_ECI_ADR_S40_FLAT f
    )
    SELECT s.*,
           'US'                                                          AS src_cntry,
           'ECI'                                                         AS src_sys,
           :P_RUN_TS                                                     AS run_ts,
           :c_mapping                                                    AS mapping_name,
           1 /* TIMELINE: VERSION_SEQ */                                 AS version_seq,
           1                                                             AS hub_state_ind,
           'Primary'                                                     AS pref_lvl,
           TO_VARCHAR(TRUNC(s.ID)) || '|' || TO_VARCHAR(TRUNC(s.ID_FAMILY_ADDRESS)) AS loc_idn,
           :P_MEMBER_HIERARCHY_CODE                                      AS hierarchy_code,
           :P_MEMBER_HM_REL_TP_CD                                        AS hm_rel_tp_cd,
           IFF(s.addr_issue_desc IS NOT NULL, 'Address', NULL)           AS exc_attribute_name,
           IFF(s.addr_issue_desc IS NOT NULL,
               NVL(s.ADDRESS1, '') || ' ' || NVL(s.ADDRESS2, '') || ' ' || NVL(s.CITY_NAME, '') || ' '
               || NVL(s.STATE_ABBREV, '') || ' ' || NVL(s.ZIP_CODE, '') || ' ' || NVL(s.ZIP_SFX, '') || ' US',
               NULL)                                                     AS exc_attribute_value,
           'Invalid_Address'                                             AS exc_code,
           'Invalid Address per Address Doctor'                          AS exc_desc,
           'Bad Value'                                                   AS exc_type,
           (ROW_NUMBER() OVER (PARTITION BY s.score, s.pkey_src_object
                                   ORDER BY s.LAST_UPDATE_DATE DESC, s.ID_FAMILY_ADDRESS) = 1
            AND xa.PKEY_SRC_OBJECT IS NULL)                              AS uq_addr,
           ROW_NUMBER() OVER (PARTITION BY s.score, s.ID, s.ID_FAMILY_ADDRESS, s.SOURCE_TABLE
                                  ORDER BY s.LAST_UPDATE_DATE DESC) = 1  AS uq_addr_exc
      FROM scored s
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_ADDR WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = s.pkey_src_object;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_ADR_S50_READY;
    RETURN :l_rows;
END;
$$;
