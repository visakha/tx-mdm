-- sp_snow_step_ECI_ADR_S10_SRC -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Addr, workflow wf_ECI_Stage_Load, step 10 (SRC_ADDRESSES).
-- Produces: WRK_ECI_ADR_S10_SRC.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_ADR_S10_SRC (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 10: SRC_ADDRESSES (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_ADR_S10_SRC AS
    WITH
    lkp_cv AS (SELECT * FROM TABLE(fn_snow_helper41_common()))
    SELECT s.SOURCE_TABLE, s.ID, s.ID_FAMILY_ADDRESS, s.ADDRESS1, s.ADDRESS2, s.ADDRESS_CD, s.CITY_NAME,
           s.COUNTY_NAME, s.STATE_ABBREV, s.ZIP_CODE, s.ZIP_SFX, s.LAST_UPDATE_DATE,
           LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')   AS pty_src_key,
           LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member'
                                                                                           AS pty_rle_fk,
           at.MSTR_CODE_VALUE                                                              AS mstr_addr_tp
      FROM V_ECI_ETL_SRC_FAMILY_ADDRESS s
      LEFT JOIN lkp_cv at ON at.CODE_TYPE = 'ADDR_TP' AND at.SRC_SYS = 'ECI'
                         AND at.SRC_CODE_VALUE = s.ADDRESS_CD;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_ADR_S10_SRC;
    RETURN :l_rows;
END;
$$;
