-- ============================================================================
-- sp_snow_pub_TRS_PTY_C_S_TRS_PTY  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY. Kind: SPINE (Valid parties).
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S4_DEDUP.
-- Keeps P_RUN_TS: Y. Original params used: P_PTY_BO_CLASS_CD_MEMBER.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PTY_C_S_TRS_PTY (

    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, GNDR_CD, SFX_NM,
            PTY_BO_CLASS_CD, FRST_NM, PRFX_NM, LST_NM, MDL_NM, FULL_NM, BIRTH_DT, VERSION_SEQ,
            PERIOD_REFERENCE_TIME, TIMELINE_ACTION, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR,
            HUB_STATE_IND, FLAG_SRC, DEATH_DT, SRC_FULL_NM, PERIOD_START_DATE, PERIOD_END_DATE, SRC_LAST_UPD_DT,
            SRC_ROWID, RACE_CD, ETHNCTY, SRC_ETHNCTY, SRC_RACE_CD)
    SELECT pkey_trim, NULL, NULL, NULL, NULL, mdm_gender_code, std_sfx_name, :P_PTY_BO_CLASS_CD_MEMBER,
           std_first_name, std_prfx_name, std_lst_name, std_mdl_name, std_full_name, std_birth_date,
           1, NULL, NULL, :P_RUN_TS, NULL, NULL, NULL, NULL, NULL, DEATH_DT, src_full_name,
           CREATE_DT, NULL, CREATE_DT, pkey_trim, race_mstr, ethnicity_mstr, ETHNICITY_CD, RACE_CD
      FROM WRK_TRS_PTY_S4_DEDUP
     WHERE rn_pty = 1 AND uq_pty;
    RETURN SQLROWCOUNT;
END;
$$;
