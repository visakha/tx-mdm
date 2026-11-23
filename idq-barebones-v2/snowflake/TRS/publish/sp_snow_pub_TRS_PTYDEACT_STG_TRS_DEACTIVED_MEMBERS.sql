-- ============================================================================
-- sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Deactivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: STG_TRS_DEACTIVED_MEMBERS. Kind: STATUS (Deactivated members).
-- Consumes (v2.1 declared inputs): WRK_TRS_DEACT1_S30_READY.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTYDEACT_STG_TRS_DEACTIVED_MEMBERS (
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
    SELECT INDV_ID, PTY_PK, SRC_TBL, CREATE_DATE, SRC_DEACTIVATION_DATE, LOAD_DATE, INACTIVE_IND, DELETE_SW,
           PROCESSED_YN
      FROM WRK_TRS_DEACT1_S30_READY;
    RETURN SQLROWCOUNT;
END;
$$;
