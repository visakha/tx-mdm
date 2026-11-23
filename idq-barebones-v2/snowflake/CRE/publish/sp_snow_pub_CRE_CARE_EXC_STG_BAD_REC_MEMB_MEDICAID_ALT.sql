-- ============================================================================
-- sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_MEDICAID_ALT  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_MEDICAID_ALT ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (MAPPING_NAME, RUN_DATE, ATTRIBUTE_NAME, SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, EXCEPTION_TYPE,
            ATTRIBUTE_VALUE, SRC_SYS_ID_1)
    SELECT mapping_name, run_ts, medicaid_tp_lbl, medicaid_tp_sys, medicaid_exception_code,
           medicaid_exception_desc, medicaid_exception_type, medicaid_alt_id, mrg_care_id
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_medicaid_exc AND uq_medicaid_exc;
    RETURN SQLROWCOUNT;
END;
$$;
