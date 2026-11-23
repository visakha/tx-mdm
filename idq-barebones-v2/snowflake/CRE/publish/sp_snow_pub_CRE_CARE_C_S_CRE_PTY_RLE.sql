-- ============================================================================
-- sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: C_S_CRE_PTY_RLE. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_CRE_PTY_RLE
           (PTY_FK, PKEY_SRC_OBJECT, SRC_ROWID, PERIOD_START_DATE, PERIOD_END_DATE, VERSION_SEQ,
            LAST_UPDATE_DATE, RLE_BO_CLASS_CD, CREATE_DATE, SRC_LAST_UPD_DT, PERIOD_REFERENCE_TIME,
            TIMELINE_ACTION)
    SELECT pty_key, rle_key, rle_key, period_start, pty_period_end, version_seq_num, run_ts,
           rle_bo_class_cd, run_ts, src_last_update, null_timestamp, null_number
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE is_member AND uq_rle;
    RETURN SQLROWCOUNT;
END;
$$;
