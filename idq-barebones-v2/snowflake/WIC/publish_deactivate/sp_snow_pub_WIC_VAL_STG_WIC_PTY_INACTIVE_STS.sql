-- ============================================================================
-- sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS.sql -- PUBLISH_DEACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_enriched);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE name_missing AND deactivation_sts IS NULL
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_VAL_STG_WIC_PTY_INACTIVE_STS (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO STG_WIC_PTY_INACTIVE_STS
           (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
    WITH
    s10_enriched AS (
WITH
        lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
        sts AS (    -- Lookup_STG_WIC_PTY_INACTIVE_STS (any row)
            SELECT i.SRC_KEY, i.DEACTIVATION_STS
              FROM STG_WIC_PTY_INACTIVE_STS i
             WHERE i.ROWID_SYSTEM = 'WIC'
           QUALIFY ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) = 1
        ),
        xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter ROWID_SYSTEM = 'WIC')
            SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND
              FROM C_B_PTY_XREF x
             WHERE TRIM(x.ROWID_SYSTEM) = 'WIC'
           QUALIFY ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) = 1
        )
        SELECT v.FIRST_NAME, v.LAST_NAME, v.MIDDLE_NAME, v.PTY_SRC_KEY,
               sts.DEACTIVATION_STS AS deactivation_sts,
               xref.HUB_STATE_IND   AS hub_state_ind,
               fn_snow_helper15_common(v.FIRST_NAME, v.MIDDLE_NAME, v.LAST_NAME,
                   TRIM(NVL(v.FIRST_NAME, '') || IFF(v.MIDDLE_NAME IS NOT NULL, ' ' || TRIM(v.MIDDLE_NAME), '')
                        || ' ' || NVL(LTRIM(v.LAST_NAME), '')),
                   NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
          FROM V_WIC_ETL_SRC v
          LEFT JOIN sts  ON sts.SRC_KEY = v.PTY_SRC_KEY
          LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = v.PTY_SRC_KEY
          LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(v.FIRST_NAME)) AND jf.IS_FIRST_JUNK
          LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(v.LAST_NAME)) AND jl.IS_LAST_JUNK
    )
    SELECT PTY_SRC_KEY AS SRC_KEY,
           'WIC' AS ROWID_SYSTEM,
           HUB_STATE_IND AS DEACTIVATION_STS,
           :P_RUN_TS AS DEACTIVATION_DT
      FROM s10_enriched;
    RETURN SQLROWCOUNT;
END;
$$;
