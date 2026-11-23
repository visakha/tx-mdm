-- sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, publish step 60 (PUBLISH_C_S_ECI_PTY_RLE_PHN).
-- Target: C_S_ECI_PTY_RLE_PHN. Consumes: WRK_ECI_PHN_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_PHN ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows    NUMBER DEFAULT 0;
BEGIN
    INSERT INTO C_S_ECI_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, PHN_NUM_EXT, HUB_STATE_IND)
    SELECT pkey_src_object, PERIOD_START_DATE, version_seq, run_ts, run_ts, src_rowid, pty_rle_fk, PHONE_TP,
           USG_TP, std_phone, PREF_LVL, PERIOD_START_DATE, WORK_EXT, hub_state_ind
      FROM WRK_ECI_PHN_S50_READY
     WHERE grp_phone_good AND uq_phn;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
