-- sp_snow_pub_ECI_PTY_C_S_ECI_PTY -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, publish step 60 (PUBLISH_C_S_ECI_PTY).
-- Target: C_S_ECI_PTY. Consumes: WRK_ECI_PTY_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_C_S_ECI_PTY ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_ECI_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR, SRC_ROWID,
            PTY_BO_CLASS_CD, PRFX_NM, FULL_NM, LST_NM, MDL_NM, FRST_NM, GNDR_CD, BIRTH_DT, SRC_FULL_NM,
            SRC_LAST_UPD_DT, BIRTH_WGHT_GRMS, HUB_STATE_IND, SRC_ETHNCTY, ETHNCTY, RACE_CD, PRFRD_LANG_CD,
            SRC_PRFRD_LANG_CD, SRC_RACE_CD, PERIOD_START_DATE)
    SELECT pkey_trim, version_seq, run_ts, MODIFIED_BY, DATE_CREATED, CREATED_BY, pkey_trim,
           pty_bo_class_cd, std_prfx_name, std_full_name, std_lst_name, std_mdl_name, std_first_name,
           mdm_gender_code, std_birth_date, std_src_full_name, DATE_MODIFIED, birth_wght_grms,
           hub_state_ind, ETHNICITY, ethnicity_mstr, mdm_race_cd, language_mstr, LANGUAGE_CD,
           src_race_ind_list, DATE_MODIFIED
      FROM WRK_ECI_PTY_S50_READY
     WHERE uq_pty;
    RETURN SQLROWCOUNT;
END;
$$;
