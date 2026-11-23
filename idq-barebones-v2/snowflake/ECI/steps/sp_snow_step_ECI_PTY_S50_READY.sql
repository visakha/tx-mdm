-- sp_snow_step_ECI_PTY_S50_READY -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty, workflow wf_ECI_Stage_Load, step 50 (ROUTED_READY).
-- Produces: WRK_ECI_PTY_S50_READY.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PTY_S50_READY (
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
    c_exc_mapping VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_OnGoing';
    l_rows        NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 50: ROUTED + READY (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PTY_S50_READY AS
    WITH
    routed AS (
        SELECT d.*,
               TRIM(d.pkey_src_object)                                   AS pkey_trim,
               TRIM(d.pkey_src_object) || '|' || :P_RLE_BO_CLASS_CD_MEMBER AS rle_pkey,
               d.gender_exception_description IS NOT NULL                AS grp_gender,
               d.birth_exception_code IS NOT NULL                        AS grp_birth,
               (d.ethnicity_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD') AS grp_ethnicity,
               (d.race_exception_desc IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD')      AS grp_race,
               (d.language_exception_code IS NOT NULL AND d.SOURCE_TABLE = 'ECI_CHILD')  AS grp_language
          FROM WRK_ECI_PTY_S40_DQ2 d
    )
    SELECT r.*,
           1                                                        AS version_seq,
           1                                                        AS hub_state_ind,
           :P_RUN_TS                                                AS run_ts,
           :c_exc_mapping                                           AS exc_mapping,
           :P_PTY_BO_CLASS_CD_MEMBER                                AS pty_bo_class_cd,
           :P_RLE_BO_CLASS_CD_MEMBER                                AS rle_bo_class_cd,
           r.BIRTH_WT_LB * 453.6 + r.BIRTH_WT_OZ * 28.35            AS birth_wght_grms,
           TO_VARCHAR(r.DOB, 'MM/DD/YYYY')                          AS dob_text,
           'Gender'                                                 AS attr_gender,
           'Birth Date'                                             AS attr_birth,
           'Ethnicity_Cd'                                           AS attr_ethnicity,
           'Race_Cd'                                                AS attr_race,
           'Language_Cd'                                            AS attr_language,
           (ROW_NUMBER() OVER (PARTITION BY r.pkey_trim ORDER BY r.DATE_MODIFIED DESC, r.ID) = 1
            AND xp.PKEY_SRC_OBJECT IS NULL)                         AS uq_pty,
           (ROW_NUMBER() OVER (PARTITION BY r.rle_pkey ORDER BY r.DATE_MODIFIED DESC, r.ID) = 1
            AND xr2.PKEY_SRC_OBJECT IS NULL)                        AS uq_rle,
           ROW_NUMBER() OVER (PARTITION BY r.grp_gender, r.pkey_src_object, r.ID, r.gender_exception_type,
                                           r.gender_exception_code ORDER BY r.ID) = 1        AS uq_gender,
           ROW_NUMBER() OVER (PARTITION BY r.grp_birth, r.pkey_src_object, r.ID, r.birth_exception_type,
                                           r.birth_exception_code ORDER BY r.ID) = 1         AS uq_birth,
           ROW_NUMBER() OVER (PARTITION BY r.grp_ethnicity, r.pkey_src_object, r.ID,
                                           r.ethnicity_exception_type, r.ethnicity_exception_code
                                  ORDER BY r.ID) = 1                                         AS uq_ethnicity,
           ROW_NUMBER() OVER (PARTITION BY r.grp_race, r.pkey_src_object, r.ID, r.race_exception_type,
                                           r.race_exception_cd ORDER BY r.ID) = 1            AS uq_race,
           ROW_NUMBER() OVER (PARTITION BY r.grp_language, r.pkey_src_object, r.ID,
                                           r.language_exception_type, r.language_exception_code
                                  ORDER BY r.ID) = 1                                         AS uq_language
      FROM routed r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY WHERE VERSION_SEQ = 1) xp
             ON xp.PKEY_SRC_OBJECT = r.pkey_trim
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE WHERE VERSION_SEQ = 1) xr2
             ON xr2.PKEY_SRC_OBJECT = r.rle_pkey;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PTY_S50_READY;
    RETURN :l_rows;
END;
$$;
