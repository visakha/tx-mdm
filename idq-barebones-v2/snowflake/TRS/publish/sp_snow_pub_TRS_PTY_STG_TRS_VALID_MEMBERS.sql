-- ============================================================================
-- sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: STG_TRS_VALID_MEMBERS. Kind: SPINE (New valid members).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S4_DEDUP.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_STG_TRS_VALID_MEMBERS (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO STG_TRS_VALID_MEMBERS (SRC_TBL, PTY_PK, INDV_ID, CREATE_DATE)
    SELECT SRC_TBL, pkey_trim, INDV_ID, :P_RUN_TS
      FROM WRK_TRS_PTY_S4_DEDUP
     WHERE rn_pty = 1 AND NOT is_valid_member;
    RETURN SQLROWCOUNT;
END;
$$;
