-- ============================================================================
-- sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_RACE -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_PTY_EXC_STG_BAD_REC_MEMB_RACE (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS_ID_2, SRC_SYS_ID_1, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE, RUN_DATE,
            FIRST_NAME, MIDDLE_NAME, LAST_NAME, GENDER, BIRTH_DATE, ATTRIBUTE_NAME, PREFIX, PERIOD_START_DATE,
            MAPPING_NAME, ATTRIBUTE_VALUE)
    SELECT CLIENTS_ID, PTY_SRC_KEY, src_sys, race_exception_code, race_exception_desc, race_exception_type,
           run_ts, FIRSTNAME, std_mdl_name, std_lst_name, gender, DOB, attr_race, std_prfx_name, SUBMITDATE,
           mapping_name, RACEETHNICITYID
      FROM WRK_TTF_PTY_S4_ROUTED
     WHERE grp_race AND uq_race;
    RETURN SQLROWCOUNT;
END;
$$;
