-- sp_snow_step_ECI_VAL_S10_SRC -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load, step 10 (SRC_DELTA_PARTIES).
-- Produces: WRK_ECI_VAL_S10_SRC.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_VAL_S10_SRC (
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
    -- ---- Step 10: CHILD + FAMILY DELTA ROWS (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_VAL_S10_SRC AS
    WITH
    src AS (
        SELECT 'ECI_CHILD' AS SOURCE_TABLE, c.ID_CHILD AS ID, c.FIRST_NAME, c.LAST_NAME, c.MIDDLE_INITIAL,
               c.DOB, c.DATE_CREATED, c.DATE_MODIFIED, c.MODIFIED_BY, c.CREATED_BY, c.LOAD_DATE
          FROM STG_ECI_D_CHILD c
        UNION ALL
        SELECT 'ECI_FAMILY' AS SOURCE_TABLE, fam.ID_FAMILY AS ID, fam.FIRST_NAME, fam.LAST_NAME,
               fam.MIDDLE_INITIAL, fam.DOB, fam.DATE_CREATED, fam.DATE_MODIFIED, fam.MODIFIED_BY,
               fam.CREATED_BY, fam.LOAD_DATE
          FROM STG_ECI_D_FAMILY fam
    )
    SELECT s.*,
           LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')   AS pkey_src_object,
           'ECI'                                                                           AS src_system,
           SUBSTR(TRIM(NVL(s.FIRST_NAME, '')
                       || IFF(s.MIDDLE_INITIAL IS NOT NULL, ' ' || TRIM(s.MIDDLE_INITIAL), '')
                       || ' ' || NVL(LTRIM(s.LAST_NAME), '')), 1, 10)                       AS full_name
      FROM src s;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_VAL_S10_SRC;
    RETURN :l_rows;
END;
$$;
