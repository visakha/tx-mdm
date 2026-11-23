-- ============================================================================
-- sp_snow_pub_TTF_PHN_EXC_STG_BAD_REC_MEMB -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PHN_EXC_STG_BAD_REC_MEMB (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
            MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME,
            SRC_SYS_ID_2)
    SELECT src_sys, phone_exception_code, phone_exception_desc, run_ts, PHONE, NULL, NULL, mapping_name,
           PTY_SRC_KEY, exc_type_rejected, SUBMITDATE, PHONE, attr_phone, NULL
      FROM WRK_TTF_PHN_S3_ROUTED
     WHERE phone_exception_code IS NOT NULL AND uq_phone_exc;
    RETURN SQLROWCOUNT;
END;
$$;
