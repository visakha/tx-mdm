-- ============================================================================
-- sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_PHN  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: C_S_CRE_PTY_RLE_PHN. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_PHN ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, SRC_ROWID, PHN_NUM, VERSION_SEQ, LAST_UPDATE_DATE, PHN_TP, PTY_RLE_FK, USG_TP,
            PREF_LVL, PERIOD_START_DATE, PERIOD_END_DATE, TIMELINE_ACTION, PERIOD_REFERENCE_TIME, CREATE_DATE,
            SRC_LAST_UPD_DT)
    SELECT phn_key, phn_src_rowid, phone_std, version_seq_num, last_update, phn_tp, member_rle_fk,
           usg_tp_phone, pref_lvl, period_start, period_end, timeline_action, period_reference_time,
           last_update, CARE_LASTUP_DT
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_phone AND uq_phone;
    RETURN SQLROWCOUNT;
END;
$$;
