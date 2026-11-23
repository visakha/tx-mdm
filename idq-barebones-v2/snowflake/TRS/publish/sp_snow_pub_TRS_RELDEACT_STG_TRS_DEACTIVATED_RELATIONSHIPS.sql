-- ============================================================================
-- sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: STG_TRS_DEACTIVATED_RELATIONSHIPS. Kind: STATUS (Deactivated relationships).
-- Consumes (v2.1 declared inputs): WRK_TRS_RELDEACT_S50_READY.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_RELDEACT_STG_TRS_DEACTIVATED_RELATIONSHIPS (
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
    SELECT INDV_ID, REF_INDV_ID, PTY_RLE_FK_1, PTY_RLE_FK_2, REL_TYPE_CODE, SRC_PKEY_CT, LOAD_DATE, PKEY_SRC_OBJECT,
           ROWID_OBJECT, MASTER_RECORD_YN, MERGED_YN, ROWID_SYSTEM, ROWID_XREF
      FROM WRK_TRS_RELDEACT_S50_READY;
    RETURN SQLROWCOUNT;
END;
$$;
