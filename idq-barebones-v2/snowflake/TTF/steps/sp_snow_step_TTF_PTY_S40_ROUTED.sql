-- ============================================================================
-- sp_snow_step_TTF_PTY_S40_ROUTED -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_PTY_S40_ROUTED (
    P_PTY_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Indv',
    P_RLE_BO_CLASS_CD_MEMBER VARCHAR DEFAULT 'Member',
    P_RUN_TS TIMESTAMP_NTZ DEFAULT NULL
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TTF_Pty';
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 40: ROUTED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_PTY_S4_ROUTED AS
    WITH
    routed AS (
        SELECT d.*,
               TRIM(d.PTY_SRC_KEY)                                        AS pkey_trim,
               TRIM(d.PTY_SRC_KEY) || '|' || :P_RLE_BO_CLASS_CD_MEMBER     AS rle_pkey,
               d.gender_exception_description IS NOT NULL                 AS grp_gender,
               d.birth_exception_code IS NOT NULL                         AS grp_birth,
               d.ethnicity_exception_code IS NOT NULL                     AS grp_ethnicity,
               d.race_exception_desc IS NOT NULL                          AS grp_race
          FROM WRK_TTF_PTY_S3_DQ2 d
    )
    SELECT r.*,
           1 /* TIMELINE: VERSION_SEQ hard-coded */         AS version_seq,
           1                                                 AS hub_state_ind,
           'TTF'                                             AS src_sys,
           :P_RUN_TS                                         AS run_ts,
           :c_mapping                                        AS mapping_name,
           :P_PTY_BO_CLASS_CD_MEMBER                         AS pty_bo_class_cd,
           :P_RLE_BO_CLASS_CD_MEMBER                         AS rle_bo_class_cd,
           TO_VARCHAR(r.DOB, 'MM/DD/YYYY')                   AS dob_text,
           'Gender'                                          AS attr_gender,
           'Birth Date'                                      AS attr_birth,
           'Ethnicity_Cd'                                    AS attr_ethnicity,
           'Race_Cd'                                         AS attr_race,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1
            AND xp.PKEY_SRC_OBJECT IS NULL)                  AS uq_pty,
           (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.SUBMITDATE DESC, r.CLIENTS_ID) = 1
            AND xr2.PKEY_SRC_OBJECT IS NULL)                 AS uq_rle,
           ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.PTY_SRC_KEY, r.CLIENTS_ID, r.gender_exception_type,
                                           r.gender_exception_code ORDER BY r.SUBMITDATE DESC) = 1 AS uq_gender,
           ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.PTY_SRC_KEY, r.CLIENTS_ID, r.birth_exception_type,
                                           r.birth_exception_code ORDER BY r.SUBMITDATE DESC) = 1  AS uq_birth,
           ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.PTY_SRC_KEY, r.CLIENTS_ID,
                                           r.ethnicity_exception_type, r.ethnicity_exception_code
                                  ORDER BY r.SUBMITDATE DESC) = 1                                  AS uq_ethnicity,
           ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.PTY_SRC_KEY, r.CLIENTS_ID, r.race_exception_type,
                                           r.race_exception_code ORDER BY r.SUBMITDATE DESC) = 1   AS uq_race
      FROM routed r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY WHERE VERSION_SEQ = 1) xp
             ON xp.PKEY_SRC_OBJECT = r.pkey_trim
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TTF_PTY_RLE WHERE VERSION_SEQ = 1) xr2
             ON xr2.PKEY_SRC_OBJECT = r.rle_pkey;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_PTY_S4_ROUTED;
    RETURN :l_rows;
END;
$$;
