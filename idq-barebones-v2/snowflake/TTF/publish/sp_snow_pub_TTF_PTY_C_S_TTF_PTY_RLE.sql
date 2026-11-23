-- ============================================================================
-- sp_snow_pub_TTF_PTY_C_S_TTF_PTY_RLE -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PTY_C_S_TTF_PTY_RLE (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TTF_PTY_RLE
           (PKEY_SRC_OBJECT, PERIOD_START_DATE, VERSION_SEQ, LAST_UPDATE_DATE, CREATE_DATE, SRC_ROWID,
            HUB_STATE_IND, PTY_FK, RLE_BO_CLASS_CD, SRC_LAST_UPD_DT)
    SELECT rle_pkey, SUBMITDATE, version_seq, run_ts, SUBMITDATE, rle_pkey, hub_state_ind, pkey_trim,
           rle_bo_class_cd, SUBMITDATE
      FROM WRK_TTF_PTY_S4_ROUTED
     WHERE uq_rle;
    RETURN SQLROWCOUNT;
END;
$$;
