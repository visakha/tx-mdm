-- ============================================================================
-- sp_snow_step_TRS_TOA_S40_RANKED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_TOA, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: TOA_RANKED. Produces: WRK_TRS_TOA_S40_RANKED.
-- Consumes (v2.1 declared inputs): WRK_TRS_TOA_S30_KEYED.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_TOA_S40_RANKED (

    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_TRS_Pty_Rle_TOA';
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 40: TOA_RANKED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_TOA_S40_RANKED AS
    WITH lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common()))
    SELECT k.*,
           'TRS' AS src_sys,
           :P_RUN_TS AS run_ts,
           :c_mapping AS mapping_name,
           'Type of Assistance' AS attr_toa,
           'Effective Date' AS attr_dates,
           xt.EXCEPTION_CODE AS toa_exc_code,
           xt.EXCEPTION_DESC AS toa_exc_desc,
           xt.EXCEPTION_TYPE AS toa_exc_type,
           'Period_Start_Date_>_Period_End_Date' AS date_exc_code,
           xd.EXCEPTION_DESC AS date_exc_desc,
           xd.EXCEPTION_TYPE AS date_exc_type,
           (ROW_NUMBER() OVER (PARTITION BY k.grp_bad_value OR k.grp_dates, k.pkey_src_object
                                   ORDER BY k.CREATE_DT DESC) = 1
            AND xa.PKEY_SRC_OBJECT IS NULL) AS uq_toa,
           ROW_NUMBER() OVER (PARTITION BY k.grp_bad_value, k.INDV_ID, k.EDG_NUM, k.MCI_CREATE_SEQ
                                  ORDER BY k.CREATE_DT DESC) = 1 AS uq_exc_toa,
           ROW_NUMBER() OVER (PARTITION BY k.grp_dates, k.pkey_src_object, k.pty_rle_fk
                                  ORDER BY k.CREATE_DT DESC) = 1 AS uq_exc_dates
      FROM WRK_TRS_TOA_S30_KEYED k
      LEFT JOIN lkp_exc xt ON xt.EXCEPTION_CODE = 'Invalid_TOA'
      LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = 'Period_Start_Date_>_Period_End_Date'
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE_TOA WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = k.pkey_src_object;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_TOA_S40_RANKED;
    RETURN :l_rows;
END;$$;
