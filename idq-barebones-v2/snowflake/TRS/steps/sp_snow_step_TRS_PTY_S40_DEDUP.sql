-- ============================================================================
-- sp_snow_step_TRS_PTY_S40_DEDUP  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_OnGoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: DEDUP_VALID. Produces: WRK_TRS_PTY_S4_DEDUP.
-- Consumes (v2.1 declared inputs): WRK_TRS_PTY_S2_DQ.
-- Original params used: P_RLE_BO_CLASS_CD_MEMBER; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTY_S40_DEDUP (

    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
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

    -- ---- Step 40: DEDUP_VALID (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_PTY_S4_DEDUP AS
    WITH
    dedup AS (
        SELECT DISTINCT pkey_trim, CREATE_DT, INDV_ID, SRC_TBL, mdm_gender_code, std_sfx_name, std_first_name,
               std_prfx_name, std_lst_name, std_mdl_name, std_birth_date, std_full_name, DEATH_DT, src_full_name,
               RACE_CD, race_mstr, race_exception_code, race_exception_desc, race_exception_type, ETHNICITY_CD,
               ethnicity_mstr, ethnicity_exception_code, ethnicity_exception_desc, ethnicity_exception_type
          FROM WRK_TRS_PTY_S2_DQ
         WHERE std_first_name IS NOT NULL OR std_lst_name IS NOT NULL
    )
    SELECT x.*,
           ROW_NUMBER() OVER (PARTITION BY x.pkey_trim
                              ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID DESC NULLS FIRST,
                                       x.SRC_TBL DESC NULLS FIRST, x.mdm_gender_code DESC NULLS FIRST,
                                       x.std_sfx_name DESC NULLS FIRST, x.std_first_name DESC NULLS FIRST,
                                       x.std_prfx_name DESC NULLS FIRST, x.std_lst_name DESC NULLS FIRST,
                                       x.std_mdl_name DESC NULLS FIRST, x.std_birth_date DESC NULLS FIRST,
                                       x.std_full_name DESC NULLS FIRST)               AS rn_pty,
           vm.PTY_PK IS NOT NULL                                                       AS is_valid_member,
           xp.PKEY_SRC_OBJECT IS NULL                                                  AS uq_pty,
           xr2.PKEY_SRC_OBJECT IS NULL                                                 AS uq_rle,
           ROW_NUMBER() OVER (PARTITION BY x.race_exception_code IS NOT NULL, x.pkey_trim,
                                           x.race_exception_type, x.race_exception_code
                                  ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID) = 1       AS uq_exc_race,
           ROW_NUMBER() OVER (PARTITION BY x.ethnicity_exception_code IS NOT NULL, x.pkey_trim,
                                           x.ethnicity_exception_type, x.ethnicity_exception_code
                                  ORDER BY x.CREATE_DT DESC NULLS FIRST, x.INDV_ID) = 1       AS uq_exc_ethnicity
      FROM dedup x
      LEFT JOIN (SELECT DISTINCT PTY_PK FROM STG_TRS_VALID_MEMBERS) vm ON vm.PTY_PK = x.pkey_trim
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY WHERE VERSION_SEQ = 1) xp
             ON xp.PKEY_SRC_OBJECT = x.pkey_trim
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE WHERE VERSION_SEQ = 1) xr2
             ON xr2.PKEY_SRC_OBJECT = x.pkey_trim || '|' || :P_RLE_BO_CLASS_CD_MEMBER;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_PTY_S4_DEDUP;
    RETURN :l_rows;
END;$$;
