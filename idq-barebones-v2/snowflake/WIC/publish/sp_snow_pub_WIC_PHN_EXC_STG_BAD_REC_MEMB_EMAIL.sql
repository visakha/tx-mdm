-- ============================================================================
-- sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_EMAIL  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (bad-e-mail exceptions).
-- WHERE guard: grp_email_bad AND uq_email_exc.
-- Reads ONLY WRK_WIC_PHN_S40_READY. Reads the run_ts / mapping_name columns materialised in the final step; it takes no parameters.
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the INSERT below is unchanged business SQL. No
-- transaction control in this proc: the driver calls it inside ONE
-- publish transaction covering all branches.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_WIC_PHN_EXC_STG_BAD_REC_MEMB_EMAIL (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, EMAIL, MAPPING_NAME, EXCEPTION_TYPE,
            PERIOD_START_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, SRC_SYS_ID_1, SRC_SYS_ID_2)
    SELECT src_sys, email_exception_code, email_exception_desc, run_ts, EMAIL, mapping_name,
           email_exception_type, DATEKEY, EMAIL, attr_email, PTY_SRC_KEY, FID
      FROM WRK_WIC_PHN_S40_READY
     WHERE grp_email_bad AND uq_email_exc;
    RETURN SQLROWCOUNT;
END;
$$;
