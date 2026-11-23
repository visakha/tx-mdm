-- ============================================================================
-- sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Pln, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_RLE_PLN. Kind: SPINE (Valid plans).
-- Consumes (v2.1 declared inputs): WRK_TRS_PLN_S30_RANKED.
-- Keeps P_RUN_TS: N. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PLN_C_S_TRS_PTY_RLE_PLN (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_RLE_PLN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, LAST_UPDATE_DATE, PTY_RLE_FK,
            PLN_FK, UPDATED_BY, CREATOR, HUB_STATE_IND, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY,
            SRC_ROWID, CREATE_DATE, SRC_LAST_UPD_DT)
    SELECT pkey_prty_rl_plan, BEGIN_DT, END_DT, version_seq, run_ts, pty_rle_fk, pln_mstr_cd, NULL, NULL,
           NULL, NULL, NULL, NULL, NULL, pkey_prty_rl_plan, run_ts, CREATE_DT
      FROM WRK_TRS_PLN_S30_RANKED
     WHERE pln_mstr_cd IS NOT NULL AND rn_key = 1 AND uq_pln;
    RETURN SQLROWCOUNT;
END;
$$;
