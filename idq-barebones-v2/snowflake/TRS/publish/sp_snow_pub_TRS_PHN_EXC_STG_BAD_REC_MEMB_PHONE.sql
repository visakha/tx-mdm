-- ============================================================================
-- sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_PHONE  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid phones).
-- Consumes (v2.1 declared inputs): WRK_TRS_PHN_S4_PHONES.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_PHN_EXC_STG_BAD_REC_MEMB_PHONE (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Phn_And_EAddr';
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (SRC_SYS, EXCEPTION_CODE, EXCEPTION_DESC, RUN_DATE, PRIMARY_PHONE, WORK_PHONE, SECONDARY_PHONE,
            MAPPING_NAME, SRC_SYS_ID_1, EXCEPTION_TYPE, SRC_SYS_ID_3, PERIOD_START_DATE, ATTRIBUTE_VALUE,
            SRC_SYS_ID_2, ATTRIBUTE_NAME)
    SELECT 'TRS', dq_exception_code, dq_exception, :P_RUN_TS,
           IFF(pref_lvl = 'Primary', phn_num, NULL),
           IFF(usg_tp = 'Work', phn_num, NULL),
           IFF(pref_lvl = 'Secondary', phn_num, NULL),
           :c_mapping, pty_fk, 'Bad Value', usg_tp, period_start_date, phn_num, case_number,
           DECODE(usg_tp, '001', 'Main Phone', '002', 'Work Phone', '003', 'Other Phone')
      FROM WRK_TRS_PHN_S4_PHONES
     WHERE dq_exception_code IS NOT NULL AND uq_exc;
    RETURN SQLROWCOUNT;
END;
$$;
