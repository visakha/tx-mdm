-- sp_snow_step_ECI_PTY_S10_SRC -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, step 10 (SRC_DELTA_PARTIES).
-- Produces: WRK_ECI_PTY_S10_SRC.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PTY_S10_SRC (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PTY_S10_SRC AS
    WITH
    src AS (
        SELECT 'ECI_CHILD' AS SOURCE_TABLE, child.ID_CHILD AS ID, child.CHILD_SSN, child.FIRST_NAME,
               child.LAST_NAME, child.MIDDLE_INITIAL, child.DOB, child.GESTATION_AGE, child.GENDER,
               child.BIRTH_WT_LB, child.BIRTH_WT_OZ, child.INTERPRET_IND, child.LANGUAGE_CD, child.RACE_CD,
               child.DATE_CREATED, COALESCE(child.DATE_MODIFIED, child.DATE_CREATED) AS DATE_MODIFIED,
               child.MODIFIED_BY, child.CREATED_BY, child.ETHNICITY, child.RACE_WHITE, child.RACE_AA,
               child.RACE_ASIAN, child.RACE_PI, child.RACE_AN, child.LOAD_DATE
          FROM STG_ECI_D_CHILD child
        UNION ALL
        SELECT 'ECI_FAMILY', fam.ID_FAMILY, NULL, fam.FIRST_NAME, fam.LAST_NAME, fam.MIDDLE_INITIAL, fam.DOB,
               NULL, fam.GENDER, NULL, NULL, NULL, NULL, NULL, fam.DATE_CREATED,
               COALESCE(fam.DATE_MODIFIED, fam.DATE_CREATED), fam.MODIFIED_BY, fam.CREATED_BY, NULL, NULL,
               NULL, NULL, NULL, NULL, fam.LOAD_DATE
          FROM STG_ECI_D_FAMILY fam
    )
    SELECT s.*,
           LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')  AS pkey_src_object,
           'Indv' AS party_type,
           'ECI'  AS src_system,
           TRIM(NVL(s.FIRST_NAME, '')
                || IFF(s.MIDDLE_INITIAL IS NOT NULL, ' ' || TRIM(s.MIDDLE_INITIAL), '')
                || ' ' || NVL(LTRIM(s.LAST_NAME), ''))                                      AS src_full_name
      FROM src s;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PTY_S10_SRC;
    RETURN :l_rows;
END;
$$;
