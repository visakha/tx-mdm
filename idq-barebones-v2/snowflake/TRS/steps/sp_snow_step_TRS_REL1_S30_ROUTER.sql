-- ============================================================================
-- sp_snow_step_TRS_REL1_S30_ROUTER  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: ROUTER_EXCEPTIONS. Produces: WRK_TRS_REL1_S3_ROUTER.
-- Consumes (v2.1 declared inputs): WRK_TRS_REL1_S2_KEYED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_REL1_S30_ROUTER (

    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 30: ROUTER_EXCEPTIONS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_REL1_S3_ROUTER AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    router AS (
        SELECT r.*,
               /* BAD DATA: unique key of EXC_STG_BAD_REC_MEMB, first row per key in this run */
               ROW_NUMBER() OVER (PARTITION BY r.pty_rle_fk_1 IS NULL, r.INDV_ID, r.REF_INDV_ID, r.rel_type_code
                                      ORDER BY r.CREATE_DT DESC) = 1   AS uq_exc_member,
               ROW_NUMBER() OVER (PARTITION BY r.pty_rle_fk_2 IS NULL, r.INDV_ID, r.REF_INDV_ID, r.rel_type_code
                                      ORDER BY r.CREATE_DT DESC) = 1   AS uq_exc_ref,
               ROW_NUMBER() OVER (PARTITION BY r.rel_type_code IS NULL, r.INDV_ID, r.REF_INDV_ID,
                                               r.RELATIONSHIP_TYPE_CD ORDER BY r.CREATE_DT DESC) = 1 AS uq_exc_type,
               ROW_NUMBER() OVER (PARTITION BY r.dates_reversed, r.INDV_ID, r.REF_INDV_ID, r.RELATIONSHIP_TYPE_CD
                                      ORDER BY r.CREATE_DT DESC) = 1   AS uq_exc_dates
          FROM WRK_TRS_REL1_S2_KEYED r
    )
    SELECT r.*,
           'Member Relationship'                         AS rel_type_code_label,
           'Member'                                      AS hierarchy_code,
           'Relationship Type'                           AS attr_rel_type,
           'Effective Date'                              AS attr_dates,
           'Invalid_Member'                              AS exc_member_code,
           xm.EXCEPTION_DESC                             AS exc_member_desc,
           xm.EXCEPTION_TYPE                             AS exc_member_type,
           'Invalid_Ref_Member'                          AS exc_ref_code,
           xf.EXCEPTION_DESC                             AS exc_ref_desc,
           xf.EXCEPTION_TYPE                             AS exc_ref_type,
           xt.EXCEPTION_CODE                             AS exc_type_lkp_code,
           xt.EXCEPTION_DESC                             AS exc_type_desc,
           xt.EXCEPTION_TYPE                             AS exc_type_type,
           'Period_Start_Date_>_Period_End_Date'         AS exc_dates_code,
           xd.EXCEPTION_DESC                             AS exc_dates_desc,
           xd.EXCEPTION_TYPE                             AS exc_dates_type
      FROM router r
      LEFT JOIN lkp_exc xm ON xm.EXCEPTION_CODE = 'Invalid_Member'
      LEFT JOIN lkp_exc xf ON xf.EXCEPTION_CODE = 'Invalid_Ref_Member'
      LEFT JOIN lkp_exc xt ON xt.EXCEPTION_CODE = 'Invalid_Rel_Type'
      LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = 'Period_Start_Date_>_Period_End_Date';
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_REL1_S3_ROUTER;
    RETURN :l_rows;
END;$$;
