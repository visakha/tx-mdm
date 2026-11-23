-- sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, publish step 80 (PUBLISH_C_S_ECI_PTY_RLE_EADDR).
-- Target: C_S_ECI_PTY_RLE_EADDR. Consumes: WRK_ECI_PHN_S50_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_PHN_C_S_ECI_PTY_RLE_EADDR ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows    NUMBER DEFAULT 0;
BEGIN
    INSERT INTO C_S_ECI_PTY_RLE_EADDR
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, PERIOD_REFERENCE_TIME, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            PTY_RLE_FK, ELEC_ADDR, USG_TP, ADDR_TP, STS_CD, IS_VLD, SRC_LAST_UPD_DT, VERSION_SEQ, HUB_STATE_IND)
    SELECT pkey_src_object, PERIOD_START_DATE, NULL, run_ts, run_ts, pkey_src_object, pty_rle_fk,
           std_email, NULL, eaddr_addr_tp, eaddr_sts_cd, eaddr_is_vld, PERIOD_START_DATE, version_seq,
           hub_state_ind
      FROM WRK_ECI_PHN_S50_READY
     WHERE grp_email_good AND uq_eaddr;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
