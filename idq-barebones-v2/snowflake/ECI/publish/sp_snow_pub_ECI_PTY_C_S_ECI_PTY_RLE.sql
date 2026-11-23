-- sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, publish step 70 (PUBLISH_C_S_ECI_PTY_RLE).
-- Target: C_S_ECI_PTY_RLE. Consumes: WRK_ECI_PTY_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PTY_C_S_ECI_PTY_RLE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_ECI_PTY_RLE
           (PKEY_SRC_OBJECT, LAST_UPDATE_DATE, CREATOR, CREATE_DATE, VERSION_SEQ, PTY_FK, SRC_LAST_UPD_DT,
            RLE_BO_CLASS_CD, PERIOD_START_DATE, HUB_STATE_IND, SRC_ROWID)
    SELECT rle_pkey, run_ts, CREATED_BY, DATE_CREATED, version_seq, pkey_trim, DATE_MODIFIED,
           rle_bo_class_cd, DATE_CREATED, hub_state_ind, rle_pkey
      FROM WRK_ECI_PTY_S50_READY
     WHERE uq_rle;
    RETURN SQLROWCOUNT;
END;
$$;
