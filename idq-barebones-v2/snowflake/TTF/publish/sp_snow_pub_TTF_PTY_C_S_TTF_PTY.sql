-- ============================================================================
-- sp_snow_pub_TTF_PTY_C_S_TTF_PTY -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PTY_C_S_TTF_PTY (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TTF_PTY
           (PKEY_SRC_OBJECT, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID, HUB_STATE_IND,
            PTY_BO_CLASS_CD, PRFX_NM, FRST_NM, MDL_NM, LST_NM, FULL_NM, GNDR_CD, SRC_FULL_NM, ETHNCTY,
            SRC_ETHNCTY, RACE_CD, SRC_RACE_CD, SRC_LAST_UPD_DT, PRFRD_LANG_CD, SFX_NM, PERIOD_START_DATE,
            BIRTH_DT)
    SELECT pkey_trim, version_seq, run_ts, SUBMITDATE, pkey_trim, hub_state_ind, pty_bo_class_cd,
           std_prfx_name, std_first_name, std_mdl_name, std_lst_name, std_full_name, mdm_gender_code,
           std_src_full_name, ethnicity_mstr, ethnicity, race_mstr, RACEETHNICITYID, SUBMITDATE, NULL, NULL,
           run_ts, std_birth_date
      FROM WRK_TTF_PTY_S4_ROUTED
     WHERE uq_pty;
    RETURN SQLROWCOUNT;
END;
$$;
