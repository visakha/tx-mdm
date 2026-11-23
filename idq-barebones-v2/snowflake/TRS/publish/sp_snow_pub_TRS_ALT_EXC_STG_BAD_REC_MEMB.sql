-- ============================================================================
-- sp_snow_pub_TRS_ALT_EXC_STG_BAD_REC_MEMB  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Alt_Id, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: EXC_STG_BAD_REC_MEMB. Kind: EXCEPTION (Invalid alt ids).
-- Consumes (v2.1 declared inputs): WRK_TRS_ALT_S4_ROUTED.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_ALT_EXC_STG_BAD_REC_MEMB (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_Alt_Id';
BEGIN
INSERT INTO EXC_STG_BAD_REC_MEMB
           (MAPPING_NAME, SRC_SYS, RUN_DATE, ATTRIBUTE_VALUE, ATTRIBUTE_NAME, EXCEPTION_DESC, EXCEPTION_CODE,
            EXCEPTION_TYPE, SRC_SYS_ID_1)
    SELECT :c_mapping, src_sys, :P_RUN_TS, alt_id_val, alt_id_label, dq_excp, dq_excp_cd, exc_type,
           pkey_src_object_pty
      FROM WRK_TRS_ALT_S4_ROUTED
     WHERE NOT is_valid AND uq_exc;
    RETURN SQLROWCOUNT;
END;
$$;
