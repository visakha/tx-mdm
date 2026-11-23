-- ============================================================================
-- sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients  --  BARE-BONES STEP DRIVER (CRE)
--
-- IDQ mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing
-- (its only mapping).
-- Install schema is CRE_ETL_WRK in database MDM_ETL_CRE; all table
-- names below are unqualified.
--
-- Bare-bones variant: no ETL_RUN_CONFIG_TBL, no job-control/checkpoint
-- calls, no P_JOB_RUN_ID, no P_INPUT_TABLES, no flag/input/publish
-- variables. The driver runs every step and every publish branch
-- unconditionally, in order, and RETURNs the big summary string built
-- with fn_snow_helper36_common. A restart is simply a new run: step 5
-- drops the previous run's work tables, then every step runs fresh.
-- Work tables are left standing at the end of a run.
-- Publish runs inside ONE transaction: all branches, or nothing.
-- On failure the transaction is rolled back and the error re-raised;
-- work tables are left in place until the next run cleans them at step 5.
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_snow_main_m_Tgt_C_S_CRE_CARE_Clients (
    P_PHYSICAL_ADDR_TYPE_CD  VARCHAR DEFAULT '002',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_DEFAULT_TX_STATE_CD    VARCHAR DEFAULT '48',
    P_COUNTY_CD_NONTX        VARCHAR DEFAULT '996',
    P_COUNTYCD_DEFAULTALL    VARCHAR DEFAULT '998',
    P_DEFAULT_NONUS_STATE_CD VARCHAR DEFAULT '99'
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_CRE_CARE_Clients';
    l_run_ts     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;
    l_rows       NUMBER DEFAULT 0;
    l_summary    VARCHAR DEFAULT '';
BEGIN
    -- ---- Step 5: CLEANUP_PREVIOUS_RUN -- drop work tables left by a previous run
    DROP TABLE IF EXISTS WRK_CRE_CARE_S1_SRC_MRG;
    DROP TABLE IF EXISTS WRK_CRE_CARE_S2_NAMED;
    DROP TABLE IF EXISTS WRK_CRE_CARE_S3_RANKED;
    DROP TABLE IF EXISTS WRK_CRE_CARE_S4_FLAT;
    DROP TABLE IF EXISTS WRK_CRE_CARE_S5_KEYED;

    -- ---- Step 10: SRC_MERGE_ROUTING
    l_rows := (CALL sp_snow_step_CRE_CARE_S10_SRC_MRG(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 10 SRC_MERGE_ROUTING', :l_rows) || CHR(10);

    -- ---- Step 20: NAME_STANDARDISE_VALIDATE
    l_rows := (CALL sp_snow_step_CRE_CARE_S20_NAMED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 20 NAME_STANDARDISE_VALIDATE', :l_rows) || CHR(10);

    -- ---- Step 30: RANK_ENRICH
    l_rows := (CALL sp_snow_step_CRE_CARE_S30_RANKED(:l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 30 RANK_ENRICH', :l_rows) || CHR(10);

    -- ---- Step 40: FLAT_ADDR_ALTID
    l_rows := (CALL sp_snow_step_CRE_CARE_S40_FLAT(:P_RLE_BO_CLASS_CD_MEMBER, :P_DEFAULT_NONUS_STATE_CD, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 40 FLAT_ADDR_ALTID', :l_rows) || CHR(10);

    -- ---- Step 50: KEYED_ROUTES_GUARDS
    l_rows := (CALL sp_snow_step_CRE_CARE_S50_KEYED(:P_PHYSICAL_ADDR_TYPE_CD, :P_RLE_BO_CLASS_CD_MEMBER, :P_DEFAULT_TX_STATE_CD, :P_COUNTY_CD_NONTX, :P_COUNTYCD_DEFAULTALL, :l_run_ts));
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 50 KEYED_ROUTES_GUARDS', :l_rows) || CHR(10);

    -- ---- PUBLISH: ONE transaction, all branches, in order ----
    BEGIN TRANSACTION;
    l_rows := (CALL sp_snow_pub_CRE_CARE_CRE_SRC_MRG());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 60 PUBLISH_CRE_SRC_MRG', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_FIRST_NAME());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 70 PUBLISH_EXC_FIRST_NAME', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_LAST_NAME());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 80 PUBLISH_EXC_LAST_NAME', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_C_S_CRE_PTY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 90 PUBLISH_C_S_CRE_PTY', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 100 PUBLISH_C_S_CRE_PTY_RLE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_GENDER());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 110 PUBLISH_EXC_GENDER', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SUFFIX());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 120 PUBLISH_EXC_SUFFIX', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ETHNICITY());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 130 PUBLISH_EXC_ETHNICITY', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_RACE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 140 PUBLISH_EXC_RACE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 150 PUBLISH_C_S_CRE_PTY_RLE_ADDR', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_ADDR());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 160 PUBLISH_EXC_ADDR', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_PHN());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 170 PUBLISH_C_S_CRE_PTY_RLE_PHN', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_PHONE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 180 PUBLISH_EXC_PHONE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_CARE());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 190 PUBLISH_ALT_ID_CARE', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_MEDICAID());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 200 PUBLISH_ALT_ID_MEDICAID', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_MEDICAID_ALT());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 210 PUBLISH_EXC_MEDICAID_ALT', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_C_S_CRE_PTY_RLE_ALT_ID_SSN());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 220 PUBLISH_ALT_ID_SSN', :l_rows) || CHR(10);
    l_rows := (CALL sp_snow_pub_CRE_CARE_EXC_STG_BAD_REC_MEMB_SSN_ALT());
    l_summary := l_summary || fn_snow_helper36_common(:c_mapping, 'step 230 PUBLISH_EXC_SSN_ALT', :l_rows) || CHR(10);
    COMMIT;

    RETURN l_summary;
EXCEPTION
    WHEN OTHER THEN
        ROLLBACK;
        RAISE;
END;
$$;
