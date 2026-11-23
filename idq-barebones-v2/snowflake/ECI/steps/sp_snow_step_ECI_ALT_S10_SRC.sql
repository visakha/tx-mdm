-- sp_snow_step_ECI_ALT_S10_SRC -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Alt_Id, workflow wf_ECI_Stage_Load, step 10 (SRC_ALT_IDS).
-- Produces: WRK_ECI_ALT_S10_SRC.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_ALT_S10_SRC (
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
    -- ---- Step 10: ALTERNATE-ID BRANCHES (verbatim from current main)
    -- Purpose: one row per alternate id -- child ECI id 018, child SSN
    -- 004 (only when present), Medicaid number 002 (via the case
    -- table), family ECI id 019. This is the original src CTE.
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_ALT_S10_SRC AS
    SELECT ID_CHILD AS ID, LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member' AS PTY_REL_FK,
           LPAD(TO_VARCHAR(ID_CHILD), 10, '0') AS SRC_KEY_SFX, '018' AS ALT_ID_TP,
           LPAD(TO_VARCHAR(ID_CHILD), 10, '0') AS ALT_ID_VAL, DATE_CREATED, DATE_MODIFIED,
           LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member' || '|018' || '|'
           || LPAD(TO_VARCHAR(ID_CHILD), 10, '0') AS PKEY_SRC_OBJECT
      FROM STG_ECI_D_CHILD
    UNION ALL
    SELECT ID_CHILD, LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member', LPAD(TO_VARCHAR(ID_CHILD), 10, '0'),
           '004', CHILD_SSN, DATE_CREATED, DATE_MODIFIED,
           LPAD(TO_VARCHAR(ID_CHILD), 10, '0') || '|Member' || '|004' || '|' || LPAD(TO_VARCHAR(ID_CHILD), 10, '0')
      FROM STG_ECI_D_CHILD
     WHERE CHILD_SSN IS NOT NULL
    UNION ALL
    SELECT C.ID_CHILD, LPAD(TO_VARCHAR(C.ID_CHILD), 10, '0') || '|Member', LPAD(TO_VARCHAR(M.ID_MEDICAID), 9, '0'),
           '002', M.MEDICAID_NBR, M.DATE_CREATED, M.DATE_MODIFIED,
           LPAD(TO_VARCHAR(C.ID_CHILD), 10, '0') || '|Member' || '|002' || '|' || LPAD(TO_VARCHAR(M.ID_MEDICAID), 10, '0')
      FROM STG_ECI_D_MEDICAID M
     INNER JOIN STG_ECI_SN_CASE C ON M.ID_CASE = C.ID_CASE
    UNION ALL
    SELECT ID_FAMILY, LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F|Member', LPAD(TO_VARCHAR(ID_FAMILY), 10, '0'),
           '019', LPAD(TO_VARCHAR(ID_FAMILY), 10, '0'), DATE_CREATED, DATE_MODIFIED,
           LPAD(TO_VARCHAR(ID_FAMILY), 10, '0') || 'F|Member' || '|019' || '|' || LPAD(TO_VARCHAR(ID_FAMILY), 10, '0')
      FROM STG_ECI_D_FAMILY;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_ALT_S10_SRC;
    RETURN :l_rows;
END;
$$;
