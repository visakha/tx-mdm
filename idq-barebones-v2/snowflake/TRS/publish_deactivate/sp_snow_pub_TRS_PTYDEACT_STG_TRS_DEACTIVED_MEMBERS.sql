-- ============================================================================
-- sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS.sql -- PUBLISH_DEACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_deactv);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO STG_TRS_DEACTIVED_MEMBERS
           (INDV_ID, PTY_PK, SRC_TBL, CREATE_DATE, SRC_DEACTIVATION_DATE, LOAD_DATE, INACTIVE_IND, DELETE_SW,
            PROCESSED_YN)
    WITH
    s10_deactv AS (
SELECT indv_id,
        inactive_ind,
        delete_sw,
        create_dt
          FROM STG_TRS_D_DC_INDV
         WHERE inactive_ind = 'Y' OR delete_sw = 'Y'
        UNION ALL
        SELECT indv_id,
        inactive_ind,
        NULL,
        create_dt
          FROM STG_TRS_D_CV_DC_MCI_INDV
         WHERE inactive_ind = 'Y'
    )
    SELECT NULL AS INDV_ID,
           NULL AS PTY_PK,
           NULL AS SRC_TBL,
           NULL AS CREATE_DATE,
           CREATE_DT AS SRC_DEACTIVATION_DATE,
           :P_RUN_TS AS LOAD_DATE,
           INACTIVE_IND AS INACTIVE_IND,
           DELETE_SW AS DELETE_SW,
           ' ' AS PROCESSED_YN
      FROM s10_deactv;
    RETURN SQLROWCOUNT;
END;
$$;
