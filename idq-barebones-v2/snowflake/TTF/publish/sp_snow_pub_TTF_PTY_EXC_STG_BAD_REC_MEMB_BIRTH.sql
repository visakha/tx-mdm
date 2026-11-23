-- ============================================================================
-- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_BIRTH -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_BIRTH (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, SRC_SYS_ID_1, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE, MAPPING_NAME,
            GENDER, ATTRIBUTE_NAME, SRC_SYS_ID_2, PREFIX, FIRST_NAME, LAST_NAME, MIDDLE_NAME, ATTRIBUTE_VALUE,
            BIRTH_DATE)
    SELECT src_sys, PTY_SRC_KEY, birth_exception_code, birth_exception_description, birth_exception_type,
           run_ts, mapping_name, gender, attr_birth, CLIENTS_ID, std_prfx_name, FIRSTNAME, LASTNAME,
           MIDDLENAME, dob_text, DOB
      FROM WRK_TTF_PTY_S4_ROUTED
     WHERE grp_birth AND uq_birth;
    RETURN SQLROWCOUNT;
END;
$$;
