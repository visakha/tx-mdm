-- sp_snow_step_ECI_REL_S10_SRC -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Rel, workflow wf_ECI_Stage_Load, step 10 (SRC_BOTH_DIRECTIONS).
-- Produces: WRK_ECI_REL_S10_SRC.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_REL_S10_SRC (
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
    -- ---- Step 10: FAMILY ROWS, BOTH DIRECTIONS (verbatim from the main)
    -- Purpose: every family row twice -- 'To Child' and 'From Child'.
    -- This is the original src CTE.
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_REL_S10_SRC AS
    SELECT d.RELATION_DIRECTION, f.ID_FAMILY, f.GENDER AS FAMILY_GENDER, f.ID_CHILD, f.FAMILY_CD,
           COALESCE(f.DATE_MODIFIED, f.DATE_CREATED) AS DATE_MODIFIED, f.DATE_CREATED
      FROM STG_ECI_D_FAMILY f
     CROSS JOIN (SELECT column1 AS RELATION_DIRECTION FROM VALUES ('From Child'), ('To Child')) d;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_REL_S10_SRC;
    RETURN :l_rows;
END;
$$;
