-- ============================================================================
-- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_GENDER -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_GENDER (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_TYPE, EXCEPTION_CODE, EXCEPTION_DESC, ATTRIBUTE_NAME, ATTRIBUTE_VALUE,
            MAPPING_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2, GENDER, BIRTH_DATE, RUN_DATE, FIRST_NAME, MIDDLE_NAME,
            LAST_NAME)
    SELECT src_sys, gender_exception_type, gender_exception_code, gender_exception_description, attr_gender,
           gender, mapping_name, PTY_SRC_KEY, CLIENTS_ID, gender, DOB, run_ts, FIRSTNAME, MIDDLENAME,
           LASTNAME
      FROM WRK_TTF_PTY_S4_ROUTED
     WHERE grp_gender AND uq_gender;
    RETURN SQLROWCOUNT;
END;
$$;
