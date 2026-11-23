-- ============================================================================
-- sp_snow_step_TTF_PTY_S30_DQ2 -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_PTY_S30_DQ2 (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: DQ2 (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_PTY_S3_DQ2 AS
    WITH
    lkp_exc  AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT d.*,
           d.nm:first_name::VARCHAR          AS std_first_name,
           d.nm:middle_name::VARCHAR         AS std_mdl_name,
           d.nm:last_name::VARCHAR           AS std_lst_name,
           d.nm:full_name::VARCHAR           AS std_full_name,
           d.nm:src_full_name::VARCHAR       AS std_src_full_name,
           d.nm:prfx_name::VARCHAR           AS std_prfx_name,
           d.gd:mdm_gender_code::VARCHAR     AS mdm_gender_code,
           d.gd:exception_code::VARCHAR      AS gender_exception_code,
           xg.EXCEPTION_DESC                 AS gender_exception_description,
           xg.EXCEPTION_TYPE                 AS gender_exception_type,
           /* BAD DATA */ IFF(d.birth_exception_code IS NULL, d.DOB, NULL) AS std_birth_date,
           xb.EXCEPTION_DESC                 AS birth_exception_description,
           xb.EXCEPTION_TYPE                 AS birth_exception_type,
           xe.EXCEPTION_CODE                 AS ethnicity_exception_code,
           xe.EXCEPTION_DESC                 AS ethnicity_exception_desc,
           xe.EXCEPTION_TYPE                 AS ethnicity_exception_type,
           xr.EXCEPTION_CODE                 AS race_exception_code,
           xr.EXCEPTION_DESC                 AS race_exception_desc,
           xr.EXCEPTION_TYPE                 AS race_exception_type
      FROM WRK_TTF_PTY_S2_DQ d
      LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = d.gd:exception_code::VARCHAR
      LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
      LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
      LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = fn_snow_helper18_common(d.race_mstr, 'Invalid_Race');
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_PTY_S3_DQ2;
    RETURN :l_rows;
END;
$$;
