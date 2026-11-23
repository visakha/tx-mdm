-- ============================================================================
-- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_ETHNICITY (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (RUN_DATE, EXCEPTION_CODE, EXCEPTION_TYPE, EXCEPTION_DESC, ATTRIBUTE_NAME, GENDER, SRC_SYS_ID_1,
            SRC_SYS, FIRST_NAME, LAST_NAME, MIDDLE_NAME, MAPPING_NAME, BIRTH_DATE, PERIOD_START_DATE,
            SRC_SYS_ID_2, ATTRIBUTE_VALUE)
    SELECT run_ts, ethnicity_exception_code, ethnicity_exception_type, ethnicity_exception_desc,
           attr_ethnicity, gender, PTY_SRC_KEY, src_sys, FIRSTNAME, std_lst_name, std_mdl_name,
           mapping_name, DOB, SUBMITDATE, CLIENTS_ID, ethnicity
      FROM WRK_TTF_PTY_S4_ROUTED
     WHERE grp_ethnicity AND uq_ethnicity;
    RETURN SQLROWCOUNT;
END;
$$;
