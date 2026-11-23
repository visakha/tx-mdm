-- sp_snow_step_ECI_ADR_S20_KEYED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Addr, workflow wf_ECI_Stage_Load, step 20 (KEYED_ACTIVE).
-- Produces: WRK_ECI_ADR_S20_KEYED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_ADR_S20_KEYED (
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
    -- ---- Step 20: KEYED_ACTIVE (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_ADR_S20_KEYED AS
    SELECT s.*,
           s.pty_rle_fk || '|' || NVL(s.mstr_addr_tp, '') || '|'
           || NVL(LPAD(TO_VARCHAR(s.ID_FAMILY_ADDRESS), 10, '0'), '') || '|'
           || NVL(TRIM(UPPER(s.ADDRESS1)), '') || '|' || NVL(TRIM(UPPER(s.ADDRESS2)), '') || '|'
           || NVL(UPPER(s.CITY_NAME), '') || '|' || NVL(UPPER(s.STATE_ABBREV), '') || '|'
           || NVL(s.ZIP_CODE, '') || '|' || NVL(s.ZIP_SFX, '')                             AS pkey_src_object
      FROM WRK_ECI_ADR_S10_SRC s
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = s.pty_src_key AND i.ROWID_SYSTEM = 'ECI'
                          AND i.DEACTIVATION_STS IS NOT NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_ADR_S20_KEYED;
    RETURN :l_rows;
END;
$$;
