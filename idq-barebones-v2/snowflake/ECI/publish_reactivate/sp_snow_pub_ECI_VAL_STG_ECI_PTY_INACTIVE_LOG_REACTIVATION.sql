-- ============================================================================
-- sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION.sql -- PUBLISH_REACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_src);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_reactivation
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_VAL_STG_ECI_PTY_INACTIVE_LOG_REACTIVATION (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 40d. Reactivation -> STG_ECI_PTY_INACTIVE_LOG (verbatim from current main)
INSERT INTO STG_ECI_PTY_INACTIVE_LOG
           (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
    WITH
    s10_src AS (
WITH
        src AS (
                SELECT 'ECI_CHILD' AS SOURCE_TABLE, c.ID_CHILD AS ID, c.FIRST_NAME, c.LAST_NAME, c.MIDDLE_INITIAL
                  FROM STG_ECI_D_CHILD c
                UNION ALL
                SELECT 'ECI_FAMILY' AS SOURCE_TABLE, fam.ID_FAMILY AS ID, fam.FIRST_NAME, fam.LAST_NAME, fam.MIDDLE_INITIAL
                  FROM STG_ECI_D_FAMILY fam
            )
        SELECT s.SOURCE_TABLE, s.ID, s.FIRST_NAME, s.LAST_NAME, s.MIDDLE_INITIAL,
               LPAD(TO_VARCHAR(s.ID), 10, '0') || IFF(s.SOURCE_TABLE = 'ECI_FAMILY', 'F', '')   AS pkey_src_object,
               'ECI'                                                                           AS src_system,
               SUBSTR(TRIM(NVL(s.FIRST_NAME, '')
                               || IFF(s.MIDDLE_INITIAL IS NOT NULL, ' ' || TRIM(s.MIDDLE_INITIAL), '')
                               || ' ' || NVL(LTRIM(s.LAST_NAME), '')), 1, 10)                       AS full_name
          FROM src s
    )
    SELECT PKEY_SRC_OBJECT AS SRC_KEY,
           SRC_SYSTEM AS ROWID_SYSTEM,
           'Reactivation' AS ACTION,
           :P_RUN_TS AS ACTION_DT
      FROM s10_src;

    RETURN SQLROWCOUNT;
END;
$$;
