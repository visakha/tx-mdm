-- ============================================================================
-- sp_snow_step_TTF_VAL_S10_ENRICHED -- BARE-BONES variant (TTF)
--
-- Mapping: m_Tgt_C_S_TTF_Pty_Validation. No config table, no checkpointing, no job-run id,
-- no input-existence check: the CTAS below is verbatim from v2.1 and
-- names its source work table literally. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TTF_VAL_S10_ENRICHED (
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
    -- ---- Step 10: ENRICHED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TTF_VAL_S1_ENRICHED AS
    WITH
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
    sts AS (    -- Lookup_STG_TTF_PTY_INACTIVE_STS (any row)
        SELECT i.SRC_KEY, i.DEACTIVATION_STS
          FROM STG_TTF_PTY_INACTIVE_STS i
         WHERE i.ROWID_SYSTEM = 'TTF'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) = 1
    ),
    xref AS (   -- Lookup_C_B_PTY_XREF (lookup filter TRIM(ROWID_SYSTEM) = 'TTF')
        SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND
          FROM C_B_PTY_XREF x
         WHERE TRIM(x.ROWID_SYSTEM) = 'TTF'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) = 1
    ),
    enriched AS (
        SELECT v.CLIENTS_ID, v.FIRSTNAME, v.LASTNAME, v.MIDDLENAME, v.DOB, v.CREATEDDATE, v.SUBMITDATE,
               v.CLIENT_EXISTS_FLAG,
               LPAD(TO_VARCHAR(v.CLIENTS_ID), 10, '0')  AS pkey_src_object,
               sts.DEACTIVATION_STS                     AS deactivation_sts,
               xref.HUB_STATE_IND                       AS hub_state_ind,
               fn_snow_helper15_common(v.FIRSTNAME, v.MIDDLENAME, v.LASTNAME,
                   TRIM(NVL(v.FIRSTNAME, '') || IFF(v.MIDDLENAME IS NOT NULL, ' ' || TRIM(v.MIDDLENAME), '')
                        || ' ' || NVL(LTRIM(v.LASTNAME), '')),
                   NULL, NULL, NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
          FROM V_TTF_ETL_SRC v
          LEFT JOIN sts  ON sts.SRC_KEY = LPAD(TO_VARCHAR(v.CLIENTS_ID), 10, '0')
          LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = LPAD(TO_VARCHAR(v.CLIENTS_ID), 10, '0')
          LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(v.FIRSTNAME)) AND jf.IS_FIRST_JUNK
          LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(v.LASTNAME)) AND jl.IS_LAST_JUNK
    )
    SELECT * FROM enriched;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TTF_VAL_S1_ENRICHED;
    RETURN :l_rows;
END;
$$;
