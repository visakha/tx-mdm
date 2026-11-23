-- ============================================================================
-- sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Target: C_S_WIC_PTY_RLE_EADDR. Kind: SPINE (valid e-mails).
-- WHERE guard: grp_email_good AND uq_eaddr.
-- Reads ONLY WRK_WIC_PHN_S40_READY. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_EADDR (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_EADDR
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_RLE_FK, ELEC_ADDR, USG_TP, STS_CD, IS_VLD, SRC_LAST_UPD_DT, ADDR_TP)
    SELECT eaddr_pkey, DATEKEY, version_seq, run_ts, run_ts, eaddr_pkey, hub_state_ind, pty_rle_fk,
           std_email, NULL, eaddr_sts_cd, eaddr_is_vld, DATEKEY, eaddr_addr_tp
      FROM WRK_WIC_PHN_S40_READY
     WHERE grp_email_good AND uq_eaddr;
    RETURN SQLROWCOUNT;
END;
$$;
