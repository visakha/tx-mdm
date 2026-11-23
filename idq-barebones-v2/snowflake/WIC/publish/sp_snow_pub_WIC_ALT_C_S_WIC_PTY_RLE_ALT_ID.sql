-- ============================================================================
-- sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Alt_Id, workflow wf_WIC_Stage_Load.
-- Target: C_S_WIC_PTY_RLE_ALT_ID. Kind: SPINE (one alternate id per active party).
-- WHERE guard: (unconditional).
-- Reads ONLY WRK_WIC_ALT_S20_READY. Uses the run timestamp directly in the INSERT.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_ALT_C_S_WIC_PTY_RLE_ALT_ID (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO C_S_WIC_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, SRC_ROWID, VERSION_SEQ, PTY_RLE_FK, ALT_ID_TP, ALT_ID_VAL, CREATE_DATE, LAST_UPDATE_DATE,
            ALT_ID_TP_FLTR, SRC_LAST_UPD_DT, STS_CD, PERIOD_START_DATE)
    SELECT x.pkey_src_object, NVL(TO_VARCHAR(x.ID), '') || '|' || x.alt_id_tp, 1 /* TIMELINE: VERSION_SEQ */,
           x.pty_rle_fk, x.alt_id_tp, LPAD(TO_VARCHAR(x.ID), 12, '0'), x.DATEKEY, :P_RUN_TS, x.alt_id_tp,
           x.DATEKEY /* IIF(IsNull(DATEKEY), DATEKEY, DATEKEY) */, 'Issued', x.DATEKEY /* TIMELINE */
      FROM WRK_WIC_ALT_S20_READY x;
    RETURN SQLROWCOUNT;
END;
$$;
