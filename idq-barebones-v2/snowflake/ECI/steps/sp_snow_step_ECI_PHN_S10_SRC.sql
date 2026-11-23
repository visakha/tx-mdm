-- sp_snow_step_ECI_PHN_S10_SRC -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, step 10 (SRC_PHN_EADDR).
-- Produces: WRK_ECI_PHN_S10_SRC.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PHN_S10_SRC (
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
    -- ---- Step 10 CTAS (verbatim from the original main procedure) ----
CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PHN_S10_SRC AS
    SELECT s.SOURCE_TABLE, s.WORK_EXT, s.PHONE_TP, s.USG_TP, s.PREF_LVL, s.PERIOD_START_DATE,
           s.PHONE_EMAIL_TYPE, s.PHONE_EMAIL, s.ID_CASE, s.ID, s.ID_FAMILY_PHONE,
           NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE)                                    AS is_email,
           NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')      AS pty_src_key,
           NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member' AS pty_rle_fk,
           IFF(NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE),
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|001|'
               || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(TRIM(s.PHONE_EMAIL), ''),
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|'
               || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '')
               || '|' || NVL(TRIM(s.PHONE_EMAIL), ''))                                     AS pkey_src_object,
           IFF(NVL(s.PHONE_EMAIL_TYPE = 'EADDRESS', FALSE),
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|001|'
               || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '') || '|' || NVL(s.PHONE_EMAIL, ''),
               NVL(TO_VARCHAR(s.ID), '') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '') || '|Member|'
               || NVL(s.PHONE_TP, '') || '|' || NVL(s.USG_TP, '') || '|' || NVL(TO_VARCHAR(s.ID_FAMILY_PHONE), '')
               || '|' || NVL(s.PHONE_EMAIL, ''))                                           AS src_rowid
      FROM V_ECI_ETL_SRC_FAMILY_PHONE s;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PHN_S10_SRC;
    RETURN :l_rows;
END;
$$;
