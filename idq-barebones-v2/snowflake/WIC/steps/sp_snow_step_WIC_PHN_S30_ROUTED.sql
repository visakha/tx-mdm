-- ============================================================================
-- sp_snow_step_WIC_PHN_S30_ROUTED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Step 30: ROUTED.
-- Produces: WRK_WIC_PHN_S30_ROUTED -- Phone and e-mail exception descriptions, codes and types resolved; good and bad routing groups for phones and e-mails.
-- Consumes: WRK_WIC_PHN_S20_CHECKED
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PHN_S30_ROUTED (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PHN_S30_ROUTED AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT c.*,
           xp.EXCEPTION_DESC AS phone_exception_desc,
           xe.EXCEPTION_CODE AS email_exception_code,
           xe.EXCEPTION_DESC AS email_exception_desc,
           xe.EXCEPTION_TYPE AS email_exception_type,
           (c.phone_exception_code IS NULL OR c.phone_exception_code = 'Missing_AreaCode') AS grp_phone_good,
           c.phone_exception_code IS NOT NULL                                            AS grp_phone_bad,
           (c.EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NULL)                            AS grp_email_good,
           (c.EMAIL IS NOT NULL AND xe.EXCEPTION_CODE IS NOT NULL)                        AS grp_email_bad
      FROM WRK_WIC_PHN_S20_CHECKED c
      LEFT JOIN lkp_exc xp ON xp.EXCEPTION_CODE = c.phone_exception_code
      LEFT JOIN lkp_exc xe ON xe.EXCEPTION_CODE = c.em:exception_code::VARCHAR;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PHN_S30_ROUTED;
    RETURN :l_rows;
END;
$$;
