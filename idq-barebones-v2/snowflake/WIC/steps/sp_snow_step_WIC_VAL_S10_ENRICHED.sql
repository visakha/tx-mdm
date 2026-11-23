-- ============================================================================
-- sp_snow_step_WIC_VAL_S10_ENRICHED  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Validation, workflow wf_WIC_Stage_Load.
-- Step 10: ENRICHED.
-- Produces: WRK_WIC_VAL_S10_ENRICHED -- Source parties joined to the current deactivation status (latest row per source key) and the cross-reference hub state, with standardised names computed. The status and cross-reference lookups stay inline here because they are reference lookups, not data stages. Only step that reads V_WIC_ETL_SRC.
-- Consumes: base tables (no work-table input)
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_VAL_S10_ENRICHED (
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
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_VAL_S10_ENRICHED AS
    WITH
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
    sts AS (    -- Lookup_STG_WIC_PTY_INACTIVE_STS (any row)
        SELECT i.SRC_KEY, i.DEACTIVATION_STS
          FROM STG_WIC_PTY_INACTIVE_STS i
         WHERE i.ROWID_SYSTEM = 'WIC'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) = 1
    ),
    xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter ROWID_SYSTEM = 'WIC')
        SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND
          FROM C_B_PTY_XREF x
         WHERE TRIM(x.ROWID_SYSTEM) = 'WIC'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) = 1
    )
    SELECT v.SOURCE_TABLE, v.ID, v.FIRST_NAME, v.LAST_NAME, v.MIDDLE_NAME, v.DOB, v.DATEKEY, v.LOAD_DATE,
           v.PTY_SRC_KEY,
           sts.DEACTIVATION_STS AS deactivation_sts,
           xref.HUB_STATE_IND   AS hub_state_ind,
           fn_snow_helper15_common(v.FIRST_NAME, v.MIDDLE_NAME, v.LAST_NAME,
               TRIM(NVL(v.FIRST_NAME, '') || IFF(v.MIDDLE_NAME IS NOT NULL, ' ' || TRIM(v.MIDDLE_NAME), '')
                    || ' ' || NVL(LTRIM(v.LAST_NAME), '')),
               NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
      FROM V_WIC_ETL_SRC v
      LEFT JOIN sts  ON sts.SRC_KEY = v.PTY_SRC_KEY
      LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = v.PTY_SRC_KEY
      LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(v.FIRST_NAME)) AND jf.IS_FIRST_JUNK
      LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(v.LAST_NAME)) AND jl.IS_LAST_JUNK;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_VAL_S10_ENRICHED;
    RETURN :l_rows;
END;
$$;
