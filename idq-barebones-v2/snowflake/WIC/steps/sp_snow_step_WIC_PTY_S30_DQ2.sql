-- ============================================================================
-- sp_snow_step_WIC_PTY_S30_DQ2  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty, workflow wf_WIC_Stage_Load.
-- Step 30: DQ2_EXCEPTION_DETAIL.
-- Produces: WRK_WIC_PTY_S30_DQ2 -- Standardised values pulled out; every exception description and type resolved from the exception lookup; birth-date value used downstream is NULL when the birth date raised an exception.
-- Consumes: WRK_WIC_PTY_S20_DQ
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PTY_S30_DQ2 (
    P_RUN_TS                 TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows NUMBER DEFAULT 0;
BEGIN
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PTY_S30_DQ2 AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
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
           d.rc:mdm_race_cd::VARCHAR         AS mdm_race_cd,
           d.rc:src_race_ind_list::VARCHAR   AS src_race_ind_list,
           xr.EXCEPTION_CODE                 AS race_exception_cd,
           xr.EXCEPTION_DESC                 AS race_exception_desc,
           xr.EXCEPTION_TYPE                 AS race_exception_type,
           xl.EXCEPTION_CODE                 AS language_exception_code,
           xl.EXCEPTION_DESC                 AS language_exception_desc,
           xl.EXCEPTION_TYPE                 AS language_exception_type
      FROM WRK_WIC_PTY_S20_DQ d
      LEFT JOIN lkp_exc xg ON xg.EXCEPTION_CODE = d.gd:exception_code::VARCHAR
      LEFT JOIN lkp_exc xb ON xb.EXCEPTION_CODE = d.birth_exception_code
      LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = fn_snow_helper18_common(d.ethnicity_mstr, 'Invalid_Ethnicity')
      LEFT JOIN lkp_exc xr ON xr.EXCEPTION_CODE = d.rc:exception_code::VARCHAR
      LEFT JOIN lkp_exc xl ON xl.EXCEPTION_CODE = fn_snow_helper18_common(d.language_mstr, 'Invalid_Language');;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PTY_S30_DQ2;
    RETURN :l_rows;
END;
$$;
