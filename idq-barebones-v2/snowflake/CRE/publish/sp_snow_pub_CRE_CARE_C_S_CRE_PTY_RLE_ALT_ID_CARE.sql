-- ============================================================================
-- sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_CARE  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: C_S_CRE_PTY_RLE_ALT_ID. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_CARE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL,
            ALT_ID_TP_FLTR, STS_CD, SRC_ROWID, SRC_LAST_UPD_DT, LAST_UPDATE_DATE, PERIOD_REFERENCE_TIME,
            TIMELINE_ACTION)
    SELECT care_alt_key, period_start, period_end, version_seq_num, rle_key, care_tp_cd, care_alt_val,
           care_tp_cd, sts_cd, care_alt_src_rowid, CARE_LASTUP_DT, last_update, null_timestamp, null_number
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_care_alt AND uq_care_alt;
    RETURN SQLROWCOUNT;
END;
$$;
