-- ============================================================================
-- sp_snow_pub_WIC_PTY_C_S_WIC_PTY  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Target: C_S_WIC_PTY. Kind: SPINE (valid parties).
-- WHERE guard: uq_pty.
-- Reads ONLY WRK_WIC_PTY_S40_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_C_S_WIC_PTY (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND, PTY_BO_CLASS_CD,
            BIRTH_WGHT_GRMS, PERIOD_START_DATE, CREATE_DATE, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD,
            BIRTH_DT, SRC_RACE_CD, RACE_CD, ETHNCTY, SRC_ETHNCTY, PRFRD_LANG_CD, SRC_LAST_UPD_DT,
            SRC_PRFRD_LANG_CD, SRC_FULL_NM)
    SELECT pkey_trim, version_seq, run_ts, pkey_trim, hub_state_ind, pty_bo_class_cd, birth_wght_grms,
           DATEKEY, DATEKEY, std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_full_name,
           mdm_gender_code, DOB, src_race_ind_list, mdm_race_cd, ethnicity_mstr, ETHNICITY, language_mstr,
           DATEKEY, LANGUAGE_CD, std_src_full_name
      FROM WRK_WIC_PTY_S40_ROUTED
     WHERE uq_pty;
    RETURN SQLROWCOUNT;
END;
$$;
