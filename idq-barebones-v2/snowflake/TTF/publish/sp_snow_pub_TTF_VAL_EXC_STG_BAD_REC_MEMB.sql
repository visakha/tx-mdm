-- ============================================================================
-- sp_snow_pub_TTF_VAL_EXC_STG_BAD_REC_MEMB -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_VAL_EXC_STG_BAD_REC_MEMB (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (PERIOD_START_DATE, MAPPING_NAME, ATTRIBUTE_NAME, FIRST_NAME, MIDDLE_NAME, LAST_NAME, RUN_DATE,
            SRC_SYS, SRC_SYS_ID_1, EXCEPTION_DESC, EXCEPTION_TYPE, EXCEPTION_CODE, BIRTH_DATE, ATTRIBUTE_VALUE)
    SELECT CREATEDDATE, mapping_name, exc_code_name /* ATTRIBUTE_NAME_Name has the same expression */,
           std_first_name, std_mdl_name, std_lst_name, run_ts, src_sys, pkey_src_object, exc_desc_name,
           exc_type_name, exc_code_name, DOB, std_src_full_name
      FROM WRK_TTF_VAL_S3_ROUTED
     WHERE grp_invalid_party_name AND uq_exc_name;
    RETURN SQLROWCOUNT;
END;
$$;
