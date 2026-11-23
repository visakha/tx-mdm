-- ============================================================================
-- sp_snow_pub_TTF_PHN_C_S_TTF_PTY_RLE_PHN -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PHN_C_S_TTF_PTY_RLE_PHN (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TTF_PTY_RLE_PHN
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, SRC_ROWID, HUB_STATE_IND,
            PTY_RLE_FK, PHN_TP, USG_TP, PHN_NUM, PREF_LVL, SRC_LAST_UPD_DT)
    SELECT phn_pkey, SUBMITDATE, version_seq, run_ts, phn_pkey, hub_state_ind, pty_rle_fk, phn_tp, usg_tp,
           std_phone, pref_lvl, SUBMITDATE
      FROM WRK_TTF_PHN_S3_ROUTED
     WHERE phone_exception_code IS NULL AND uq_phn;
    RETURN SQLROWCOUNT;
END;
$$;
