-- sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Alt_Id, workflow wf_ECI_Stage_Load, publish step 50 (PUBLISH_C_S_ECI_PTY_RLE_ALT_ID).
-- Target: C_S_ECI_PTY_RLE_ALT_ID. Consumes: WRK_ECI_ALT_S40_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_ALT_C_S_ECI_PTY_RLE_ALT_ID ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Publish branch 50a: valid alternate ids -> C_S_ECI_PTY_RLE_ALT_ID (SPINE, verbatim)
    INSERT INTO C_S_ECI_PTY_RLE_ALT_ID
           (PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, CREATE_DATE, LAST_UPDATE_DATE, PKEY_SRC_OBJECT, SRC_ROWID,
            VERSION_SEQ, STS_CD, HUB_STATE_IND, SRC_LAST_UPD_DT, ALT_ID_TP_FLTR, PERIOD_START_DATE)
    SELECT PTY_REL_FK, ALT_ID_TP, ALT_ID_VAL, DATE_CREATED, run_ts, PKEY_SRC_OBJECT, src_rowid,
           version_seq, sts_cd, hub_state_ind, src_last_upd_dt, ALT_ID_TP, DATE_CREATED
      FROM WRK_ECI_ALT_S40_READY
     WHERE grp_valid AND uq_alt_id;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
