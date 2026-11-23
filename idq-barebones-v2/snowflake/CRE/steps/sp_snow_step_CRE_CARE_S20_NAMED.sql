-- ============================================================================
-- sp_snow_step_CRE_CARE_S20_NAMED  --  BARE-BONES STEP (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing, step 20.
-- Produces WRK_CRE_CARE_S2_NAMED; consumes WRK_CRE_CARE_S1_SRC_MRG.
-- Original parameters used: none.
--
-- Bare-bones variant: no P_JOB_RUN_ID, no P_INPUT_TABLES, no
-- existence check, no checkpoint call. The CTAS below is the
-- v2.1 step SELECT verbatim; only the dropped parameters and
-- framework blocks were removed. No exception block (errors
-- propagate to the driver handler), no transaction, no target write.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_CRE_CARE_S20_NAMED (
    P_RUN_TS       TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 20: NAME_STANDARDISE_VALIDATE (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_CRE_CARE_S2_NAMED AS
    WITH
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
    lkp_cv   AS (SELECT * FROM TABLE(fn_snow_helper41_common())),
    -- Union + mplt_Name_Standardization_Indv_Member (first, last, suffix and source system linked)
    named AS (
        SELECT r.*,
               IFF(r.grp_deletes, NULL, IFF(r.no_merge_history, 'N', 'Y'))            AS orig_rowid_object_desc,
               fn_snow_helper15_common(r.FIRSTNM, NULL, r.LASTNM, NULL, NULL, r.LAST_SUF, NULL,
                                       sf.MSTR_CODE_VALUE, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
          FROM WRK_CRE_CARE_S1_SRC_MRG r
          LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(r.FIRSTNM)) AND jf.IS_FIRST_JUNK
          LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(r.LASTNM)) AND jl.IS_LAST_JUNK
          LEFT JOIN lkp_cv sf ON sf.CODE_TYPE = 'SUFFIX' AND sf.SRC_SYS = 'CRE' AND sf.SRC_CODE_VALUE = r.LAST_SUF
    )
    -- rtr_Valid_Members, EXP_INVALID_MEMBERS, EXP_VALID_MEMBERS
    SELECT n.*,
           n.nm:first_name::VARCHAR                                                AS std_first_name,
           n.nm:last_name::VARCHAR                                                 AS std_lst_name,
           n.nm:full_name::VARCHAR                                                 AS std_full_name,
           n.nm:src_full_name::VARCHAR                                             AS std_src_full_name,
           n.nm:sfx_name::VARCHAR                                                  AS std_sfx_name,
           n.nm:src_suffix::VARCHAR                                                AS src_suffix,
           n.nm:suffix_exception_code::VARCHAR                                     AS suffix_exception_code,
           /* VALIDATION */
           NVL(LENGTH(TRIM(n.nm:first_name::VARCHAR)) > 0 AND LENGTH(TRIM(n.nm:last_name::VARCHAR)) > 0,
               FALSE)                                                              AS valid_member,
           IFF(fn_snow_helper03_common(n.nm:first_name::VARCHAR), 'Missing_First_Name', NULL) AS fn_missing_code,
           IFF(fn_snow_helper03_common(n.nm:last_name::VARCHAR), 'Missing_Last_Name', NULL)   AS ln_missing_code,
           n.REC_TYPE IN ('B', 'D')                                                AS end_dated
      FROM named n;
    SELECT COUNT(*) INTO :l_rows FROM WRK_CRE_CARE_S2_NAMED;
    RETURN :l_rows;
END;
$$;
