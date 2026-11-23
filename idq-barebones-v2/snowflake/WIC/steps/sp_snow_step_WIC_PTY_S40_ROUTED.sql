-- ============================================================================
-- sp_snow_step_WIC_PTY_S40_ROUTED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Step 40: ROUTED.
-- Produces: WRK_WIC_PTY_S40_ROUTED -- Party and role keys, exception routing groups, run constants, birth weight in grams, and the insert-only guards (uq_pty, uq_rle, uq_gender, uq_birth, uq_ethnicity, uq_race, uq_language). Guards evaluated here, before publish, as in the original single query.
-- Consumes: WRK_WIC_PTY_S30_DQ2
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PTY_S40_ROUTED (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows NUMBER DEFAULT 0;
BEGIN
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PTY_S40_ROUTED AS
    WITH
    routed AS (
        SELECT d.*,
               TRIM(d.PTY_SRC_KEY)                                                    AS pkey_trim,
               TRIM(d.PTY_SRC_KEY) || '|' || :P_RLE_BO_CLASS_CD_MEMBER                 AS rle_pkey,
               (d.gender_exception_description IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT') AS grp_gender,
               d.birth_exception_code IS NOT NULL                                     AS grp_birth,
               (d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT')  AS grp_ethnicity,
               (d.race_exception_desc IS NOT NULL AND d.SOURCE_TABLE = 'CLIENT')       AS grp_race,
               d.language_exception_code IS NOT NULL                                  AS grp_language
          FROM WRK_WIC_PTY_S30_DQ2 d
    )
    SELECT r.*,
           1 /* TIMELINE: VERSION_SEQ hard-coded */         AS version_seq,
           1                                                 AS hub_state_ind,
           'WIC'                                             AS src_sys,
           :P_RUN_TS                                         AS run_ts,
           :c_mapping                                        AS mapping_name,
           :P_PTY_BO_CLASS_CD_MEMBER                         AS pty_bo_class_cd,
           :P_RLE_BO_CLASS_CD_MEMBER                         AS rle_bo_class_cd,
           r.BIRTH_WT_OZ * 28.35                             AS birth_wght_grms,
           TO_VARCHAR(r.DOB, 'MM/DD/YYYY')                   AS dob_text,
           'Gender'                                          AS attr_gender,
           'Birth Date'                                      AS attr_birth,
           'Ethnicity_Cd'                                    AS attr_ethnicity,
           'Race_Cd'                                         AS attr_race,
           'Language_Cd'                                     AS attr_language,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.DATEKEY DESC, r.ID) = 1
            AND xp.PKEY_SRC_OBJECT IS NULL)                  AS uq_pty,
           (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DATEKEY DESC, r.ID) = 1
            AND xr2.PKEY_SRC_OBJECT IS NULL)                 AS uq_rle,
           ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.ID, r.gender_exception_type,
                                           r.gender_exception_code ORDER BY r.DATEKEY DESC) = 1   AS uq_gender,
           ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.ID, r.birth_exception_type,
                                           r.birth_exception_code ORDER BY r.DATEKEY DESC) = 1    AS uq_birth,
           ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.ID, r.ethnicity_exception_type,
                                           r.ethnicity_exception_code ORDER BY r.DATEKEY DESC) = 1 AS uq_ethnicity,
           ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.ID, r.race_exception_type,
                                           r.race_exception_cd ORDER BY r.DATEKEY DESC) = 1       AS uq_race,
           ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.PTY_SRC_KEY, r.ID, r.language_exception_type,
                                           r.language_exception_code ORDER BY r.DATEKEY DESC) = 1 AS uq_language
      FROM routed r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY WHERE VERSION_SEQ = 1) xp
             ON xp.PKEY_SRC_OBJECT = r.pkey_trim
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE WHERE VERSION_SEQ = 1) xr2
             ON xr2.PKEY_SRC_OBJECT = r.rle_pkey;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PTY_S40_ROUTED;
    RETURN :l_rows;
END;
$$;
