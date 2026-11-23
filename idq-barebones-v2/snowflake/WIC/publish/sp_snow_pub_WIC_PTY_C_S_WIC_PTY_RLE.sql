-- ============================================================================
-- sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Target: C_S_WIC_PTY_RLE. Kind: SPINE (valid roles).
-- WHERE guard: uq_rle.
-- Reads ONLY WRK_WIC_PTY_S40_ROUTED. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PTY_C_S_WIC_PTY_RLE (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE
           (PKEY_SRC_OBJECT, SRC_ROWID, RLE_BO_CLASS_CD, PTY_FK, VERSION_SEQ, LAST_UPDATE_DATE, HUB_STATE_IND,
            CREATE_DATE, PERIOD_START_DATE, SRC_LAST_UPD_DT)
    SELECT rle_pkey, rle_pkey, rle_bo_class_cd, pkey_trim, version_seq, run_ts, hub_state_ind, DATEKEY,
           DATEKEY, DATEKEY
      FROM WRK_WIC_PTY_S40_ROUTED
     WHERE uq_rle;
    RETURN SQLROWCOUNT;
END;
$$;
