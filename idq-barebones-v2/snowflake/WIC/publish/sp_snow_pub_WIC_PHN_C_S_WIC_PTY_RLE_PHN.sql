-- ============================================================================
-- sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_PHN  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Target: C_S_WIC_PTY_RLE_PHN. Kind: SPINE (good phones).
-- WHERE guard: grp_phone_good AND uq_phn.
-- Reads ONLY WRK_WIC_PHN_S40_READY. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PHN_C_S_WIC_PTY_RLE_PHN (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, PTY_RLE_FK, PHN_TP,
            USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT, HUB_STATE_IND)
    SELECT phn_pkey, DATEKEY, version_seq, run_ts, phn_pkey, pty_rle_fk, phn_tp, usg_tp, std_phone, pref_lvl,
           DATEKEY, hub_state_ind
      FROM WRK_WIC_PHN_S40_READY
     WHERE grp_phone_good AND uq_phn;
    RETURN SQLROWCOUNT;
END;
$$;
