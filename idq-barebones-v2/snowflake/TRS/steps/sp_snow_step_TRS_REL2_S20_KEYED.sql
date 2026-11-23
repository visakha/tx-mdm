-- ============================================================================
-- sp_snow_step_TRS_REL2_S20_KEYED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: KEYED. Produces: WRK_TRS_REL2_S2_KEYED.
-- Consumes (v2.1 declared inputs): WRK_TRS_REL2_S1_SRC.
-- Original params used: P_PCP_REL_TP; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_REL2_S20_KEYED (

    P_PCP_REL_TP VARCHAR DEFAULT '100',
    P_RUN_TS                 TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN

    -- ---- Step 20: KEYED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_REL2_S2_KEYED AS
    WITH
    tpi_src_key AS (
        SELECT bo.alt_id_val, xr.pkey_src_object
          FROM C_B_PTY_RLE_ALT_ID bo
         INNER JOIN C_B_PTY_RLE_ALT_ID_XREF xr ON bo.rowid_object = xr.rowid_object
         WHERE bo.alt_id_tp = '006' AND TRIM(xr.rowid_system) = 'C21' AND xr.hub_state_ind = 1
       QUALIFY ROW_NUMBER() OVER (PARTITION BY bo.alt_id_val ORDER BY xr.src_last_upd_dt DESC) = 1
    ),
    keyed AS (
        SELECT s.*,
               IFF(s.PTY_PK IS NULL, NULL, TRIM(s.PTY_PK) || '|Member')                        AS pty_rle_fk_1,
               SUBSTR(TRIM(t.pkey_src_object), 1, REGEXP_INSTR(TRIM(t.pkey_src_object), '[|]', 1, 2) - 1)
                                                                                              AS pty_rle_fk_2,
               IFF(CONTAINS(TRIM(t.pkey_src_object), '|HCO'), 'Member PCO', 'Member PCP')     AS rel_type_code
          FROM WRK_TRS_REL2_S1_SRC s
          LEFT JOIN tpi_src_key t ON t.alt_id_val = s.PROVIDER_NUM
    )
    SELECT k.*,
           NVL(k.pty_rle_fk_1, '') || '|' || NVL(k.pty_rle_fk_2, '') || '|' || :P_PCP_REL_TP AS pkey_src_object,
           /* VALIDATION */ NVL(k.BEGIN_DT > k.END_DT, FALSE)                              AS dates_reversed,
           /* VALIDATION */ (k.pty_rle_fk_1 IS NOT NULL AND k.pty_rle_fk_2 IS NOT NULL
                             AND NVL(k.BEGIN_DT <= k.END_DT OR k.END_DT IS NULL, FALSE))   AS is_valid
      FROM keyed k;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_REL2_S2_KEYED;
    RETURN :l_rows;
END;$$;
