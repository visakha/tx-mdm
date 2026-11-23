-- ============================================================================
-- sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW.sql -- PUBLISH_DEACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE grp_deactivation AND deactivation_sts IS NULL
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_FSS_VAL_STG_FSS_PTY_INACTIVE_STS_NEW (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO STG_FSS_PTY_INACTIVE_STS
           (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
    WITH
    s1_src AS (
SELECT v.PTY_SRC_KEY,
       v.NM_FIRST,
       v.NM_LAST,
       v.NM_MIDDLE,
       v.CLIENT_DTL__CAPXACTION,
       v.LAST_INACTV_CLIENT_YN
FROM v_fss_etl_src v
WHERE (v.LAST_ACTIVE_CLIENT_REGISTRATION_YN = 'Y' OR v.LAST_INACTV_CLIENT_YN = 'Y')
    )
    SELECT PTY_SRC_KEY AS SRC_KEY,
           'FSS' AS ROWID_SYSTEM,
           NULL AS DEACTIVATION_STS,
           :P_RUN_TS AS DEACTIVATION_DT
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
