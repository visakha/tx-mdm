-- sp_snow_step_ECI_VAL_S20_ENRICHED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Validation, workflow wf_ECI_Stage_Load, step 20 (ENRICHED_STD_NAMES).
-- Produces: WRK_ECI_VAL_S20_ENRICHED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_VAL_S20_ENRICHED (
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
    -- ---- Step 20: LOOKUPS + NAME STANDARDISATION (verbatim from current main)
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_VAL_S20_ENRICHED AS
    WITH
    lkp_junk AS (SELECT * FROM TABLE(fn_snow_helper43_common())),
    sts AS (
        SELECT i.SRC_KEY, i.ROWID_SYSTEM, i.DEACTIVATION_STS
          FROM STG_ECI_PTY_INACTIVE_STS i
       QUALIFY ROW_NUMBER() OVER (PARTITION BY i.SRC_KEY, i.ROWID_SYSTEM
                                      ORDER BY i.DEACTIVATION_DT DESC NULLS LAST) = 1
    ),
    xref AS (
        SELECT x.PKEY_SRC_OBJECT, x.HUB_STATE_IND
          FROM C_B_PTY_XREF x
         WHERE TRIM(x.ROWID_SYSTEM) = 'ECI'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY x.PKEY_SRC_OBJECT ORDER BY x.HUB_STATE_IND DESC NULLS LAST) = 1
    ),
    dup AS (
        SELECT DISTINCT d.SOURCE_TABLE, d.ID FROM V_ECI_ETL_LU_DUP_CASES d
    ),
    fam AS (
        SELECT f.SOURCE_TABLE, f.ID_FAMILY, f.FAM_NAME_STATUS, f.FAM_PHONE_AND_ADDRESS_STS, f.FAM_INACTIVE_STS
          FROM V_ECI_ETL_LU_FAMILY_VALIDATION f
       QUALIFY ROW_NUMBER() OVER (PARTITION BY f.SOURCE_TABLE, f.ID_FAMILY ORDER BY f.ID_FAMILY) = 1
    )
    SELECT e.*,
           sts.DEACTIVATION_STS                                                    AS deactivation_sts,
           xref.HUB_STATE_IND                                                      AS hub_state_ind,
           dup.ID                                                                  AS omit_id,
           IFF(fam.FAM_NAME_STATUS IS NULL AND fam.FAM_PHONE_AND_ADDRESS_STS IS NULL
               AND fam.FAM_INACTIVE_STS IS NULL, 'N', 'Y')                         AS fam_inactive_yn,
           fn_snow_helper15_common(e.FIRST_NAME, e.MIDDLE_INITIAL, e.LAST_NAME, e.full_name, NULL, NULL,
                                   NULL, NULL, jf.NAME IS NOT NULL, jl.NAME IS NOT NULL) AS nm
      FROM WRK_ECI_VAL_S10_SRC e
      LEFT JOIN sts  ON sts.SRC_KEY = e.pkey_src_object AND sts.ROWID_SYSTEM = e.src_system
      LEFT JOIN xref ON xref.PKEY_SRC_OBJECT = e.pkey_src_object
      LEFT JOIN dup  ON dup.SOURCE_TABLE = e.SOURCE_TABLE AND dup.ID = e.ID
      LEFT JOIN fam  ON fam.SOURCE_TABLE = e.SOURCE_TABLE AND fam.ID_FAMILY = e.ID
      LEFT JOIN lkp_junk jf ON jf.NAME = UPPER(TRIM(e.FIRST_NAME)) AND jf.IS_FIRST_JUNK
      LEFT JOIN lkp_junk jl ON jl.NAME = UPPER(TRIM(e.LAST_NAME)) AND jl.IS_LAST_JUNK;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_VAL_S20_ENRICHED;
    RETURN :l_rows;
END;
$$;
