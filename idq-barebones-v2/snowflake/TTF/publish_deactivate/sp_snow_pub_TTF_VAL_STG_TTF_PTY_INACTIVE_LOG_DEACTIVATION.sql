-- ============================================================================
-- sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_DEACTIVATION.sql -- PUBLISH_DEACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_DEACTIVATION.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_enriched);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_deactivation
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_LOG_DEACTIVATION (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO STG_TTF_PTY_INACTIVE_LOG
           (SRC_KEY, ROWID_SYSTEM, ACTION, ACTION_DT)
    WITH
    s1_enriched AS (
WITH
        lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
        enriched AS (
            SELECT v.FIRSTNAME, v.LASTNAME, v.MIDDLENAME,
                   v.CLIENT_EXISTS_FLAG,
                   LPAD(TO_VARCHAR(v.CLIENTS_ID), 10, '0')  AS pkey_src_object,
                   fn_snow_helper15_common(v.FIRSTNAME, v.MIDDLENAME, v.LASTNAME,
                       TRIM(NVL(v.FIRSTNAME, '') || IFF(v.MIDDLENAME IS NOT NULL, ' ' || TRIM(v.MIDDLENAME), '')
                            || ' ' || NVL(LTRIM(v.LASTNAME), '')),
                       NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
              FROM V_TTF_ETL_SRC v
              LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(v.FIRSTNAME)) AND jf.IS_FIRST_JUNK
              LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(v.LASTNAME)) AND jl.IS_LAST_JUNK
        )
        SELECT * FROM enriched
    )
    SELECT PKEY_SRC_OBJECT AS SRC_KEY,
           'TTF' AS ROWID_SYSTEM,
           'Deactivation' AS ACTION,
           :P_RUN_TS AS ACTION_DT
      FROM s1_enriched;
    RETURN SQLROWCOUNT;
END;
$$;
