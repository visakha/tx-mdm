-- ============================================================================
-- sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS.sql -- PUBLISH_DEACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_minpk);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: YES
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO STG_TRS_DEACTIVATED_RELATIONSHIPS
           (INDV_ID, REF_INDV_ID, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE, SRC_PKEY_CT, LOAD_DATE, PKEY_SRC_OBJECT,
            ROWID_OBJECT, MASTER_RECORD_YN, MERGED_YN, ROWID_SYSTEM, ROWID_XREF)
    WITH
    s10_minpk AS (
SELECT indv_id,
        MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
    )
    SELECT NULL AS INDV_ID,
           NULL AS REF_INDV_ID,
           IFF(PTY_PK IS NULL, NULL, TRIM(PTY_PK) || '       ') AS PTY_RLE_FK_1,
           IFF(PTY_PK IS NULL, NULL, TRIM(PTY_PK) || '       ') AS PTY_RLE_FK_2,
           NULL AS REL_TYPE_CODE,
           NULL AS SRC_PKEY_CT,
           :P_RUN_TS AS LOAD_DATE,
           NULL AS PKEY_SRC_OBJECT,
           NULL AS ROWID_OBJECT,
           NULL AS MASTER_RECORD_YN,
           NULL AS MERGED_YN,
           '   ' AS ROWID_SYSTEM,
           NULL AS ROWID_XREF
      FROM s10_minpk;
    RETURN SQLROWCOUNT;
END;
$$;
