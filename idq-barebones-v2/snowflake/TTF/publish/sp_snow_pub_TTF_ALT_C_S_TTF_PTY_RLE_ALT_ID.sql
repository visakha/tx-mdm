-- ============================================================================
-- sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_ALT_C_S_TTF_PTY_RLE_ALT_ID (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TTF_PTY_RLE_ALT_ID
           (PKEY_SRC_OBJECT, HUB_STATE_IND, SRC_ROWID, LAST_UPDATE_DATE, VERSION_SEQ, CREATE_DATE, PTY_RLE_FK,
            ALT_ID_TP, ALT_ID_VAL, ALT_ID_TP_FLTR, STS_CD, PERIOD_START_DATE, SRC_LAST_UPD_DT)
    SELECT k.pkey_src_object, 1, k.pkey_src_object, :P_RUN_TS, 1 /* TIMELINE: VERSION_SEQ */, k.SUBMITDATE,
           NVL(k.PTY_SRC_KEY, '') || '|Member', '024', k.PTY_SRC_KEY, '024', 'Issued',
           :P_RUN_TS /* TIMELINE: $sys.MappingRunStartTime */, k.SUBMITDATE
      FROM WRK_TTF_ALT_S2_DEDUP k;
    RETURN SQLROWCOUNT;
END;
$$;
