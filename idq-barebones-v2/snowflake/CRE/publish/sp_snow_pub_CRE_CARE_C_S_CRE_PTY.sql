-- ============================================================================
-- sp_snow_pub_CRE_CARE_C_S_CRE_PTY  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: C_S_CRE_PTY. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_C_S_CRE_PTY ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_CRE_PTY
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PERIOD_REFERENCE_TIME,
            TIMELINE_ACTION, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID, BIRTH_DT, FULL_NM, GNDR_CD, SFX_NM,
            LST_NM, FRST_NM, PTY_BO_CLASS_CD, SRC_FULL_NM, SRC_LAST_UPD_DT, ETHNCTY, RACE_CD, SRC_ETHNCTY,
            SRC_RACE_CD)
    SELECT pty_key, period_start, pty_period_end, version_seq_num, pty_period_reference_time,
           timeline_action, last_update, last_update, pty_key, BIRTH_DT, std_full_name, mdm_gender_code,
           std_sfx_name, std_lst_name, std_first_name, pty_bo_class_cd, std_src_full_name, src_last_update,
           ethnicity_mstr, race_mstr, FEDETH, RACE
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE is_member AND uq_pty;
    RETURN SQLROWCOUNT;
END;
$$;
