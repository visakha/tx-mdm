-- sp_snow_step_ECI_REL_S20_KEYED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Rel, workflow wf_ECI_Stage_Load, step 20 (KEYED_BOTH_ACTIVE).
-- Produces: WRK_ECI_REL_S20_KEYED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_REL_S20_KEYED (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows     NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 20: PARTY KEYS + BOTH PARTIES ACTIVE (verbatim from the main)
    -- Purpose: build the child and family party keys and keep only
    -- rows where NEITHER party has a deactivation status. This is the
    -- original keyed CTE.
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_REL_S20_KEYED AS
    SELECT s.*,
           LPAD(TO_VARCHAR(s.ID_CHILD), 10, '0')          AS child_pty_src_key,
           LPAD(TO_VARCHAR(s.ID_FAMILY), 10, '0') || 'F'  AS family_pty_src_key
      FROM WRK_ECI_REL_S10_SRC s
     WHERE NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = LPAD(TO_VARCHAR(s.ID_CHILD), 10, '0') AND i.ROWID_SYSTEM = 'ECI'
                          AND i.DEACTIVATION_STS IS NOT NULL)
       AND NOT EXISTS (SELECT 1 FROM STG_ECI_PTY_INACTIVE_STS i
                        WHERE i.SRC_KEY = LPAD(TO_VARCHAR(s.ID_FAMILY), 10, '0') || 'F'
                          AND i.ROWID_SYSTEM = 'ECI' AND i.DEACTIVATION_STS IS NOT NULL);
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_REL_S20_KEYED;
    RETURN :l_rows;
END;
$$;
