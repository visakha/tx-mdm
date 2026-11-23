-- ============================================================================
-- sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID.sql -- PUBLISH_DEST S10-only twin (C_S_* spine, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s1_src);
-- every later step (ACTIVE / DQ / ROUTED / READY / ranked / router)
-- and the WHERE gate are dropped. Each target column is aliased
-- from a first-step column, a literal, or a parameter (see map).
-- A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: WHERE is_valid AND uq_alt_id
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_ALT_C_S_TRS_PTY_RLE_ALT_ID (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, SRC_ROWID, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, ALT_ID_TP, ALT_ID_VAL,
            STS_CD, ALT_ID_TP_FLTR, CV_IND, PTY_RLE_FK, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY,
            PERIOD_END_DATE, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, UPDATED_BY, CREATE_DATE, CREATOR,
            HUB_STATE_IND, SRC_LAST_UPD_DT)
    WITH
    s1_src AS (
WITH
        all_indv AS (
            SELECT DISTINCT TO_VARCHAR(mci_indv.indv_id) AS pty_pkey,
        mci_indv.indv_id AS member_id,
        mci_indv.create_dt,
        mci_indv.ssn,
        ' ' AS cv_ind
              FROM STG_TRS_D_CV_DC_MCI_INDV mci_indv
            UNION ALL
            SELECT DISTINCT TO_VARCHAR(indv.indv_id) || '        ',
        indv.indv_id,
        indv.create_dt,
        indv.ssn,
        NULL
              FROM STG_TRS_D_DC_INDV indv
            UNION ALL
            SELECT DISTINCT TO_VARCHAR(mrg.old_indv_id),
        mrg.indv_id,
        mrg.create_dt,
        NULL,
        NULL
              FROM STG_TRS_D_CV_DC_MRG_SPRT_INDV mrg
             WHERE mrg.type_cd = 'ME'
        ),
        de_dup_indv AS (
            SELECT a.pty_pkey,
        TO_VARCHAR(a.member_id) AS member_id,
        a.create_dt AS start_dt,
        a.ssn,
        a.cv_ind,
        ROW_NUMBER() OVER (PARTITION BY a.pty_pkey
                                      ORDER BY LENGTH(TO_VARCHAR(a.ssn)) DESC NULLS LAST, a.create_dt DESC) AS key_rn
              FROM all_indv a
              JOIN STG_TRS_VALID_MEMBERS vm ON a.pty_pkey = vm.pty_pk
        )
        SELECT pty_pkey AS PTY_PKEY,
        member_id AS MEMBER_ID,
        start_dt AS START_DT,
        ssn AS SSN,
        cv_ind AS CV_IND
          FROM de_dup_indv
         WHERE key_rn = 1
    )
    SELECT NULL AS PKEY_SRC_OBJECT,
           NULL AS SRC_ROWID,
           NULL AS PERIOD_START_DATE,
           1 AS VERSION_SEQ,
           :P_RUN_TS AS LAST_UPDATE_DATE,
           NULL AS ALT_ID_TP,
           NULL AS ALT_ID_VAL,
           '      ' AS STS_CD,
           NULL AS ALT_ID_TP_FLTR,
           NULL AS CV_IND,
           NULL AS PTY_RLE_FK,
           NULL AS ROWID_OBJECT,
           NULL AS DELETED_IND,
           NULL AS DELETED_DATE,
           NULL AS DELETED_BY,
           NULL AS PERIOD_END_DATE,
           NULL AS PERIOD_REFERENCE_TIME,
           NULL AS TIMELINE_ACTION,
           NULL AS UPDATED_BY,
           NULL AS CREATE_DATE,
           NULL AS CREATOR,
           NULL AS HUB_STATE_IND,
           NULL AS SRC_LAST_UPD_DT
      FROM s1_src;
    RETURN SQLROWCOUNT;
END;
$$;
