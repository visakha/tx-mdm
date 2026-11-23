-- ============================================================================
-- sp_snow_step_TRS_REL2_S60_TIMELINE  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_2_Mem_To_PCP, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: TIMELINE. Produces: WRK_TRS_REL2_S6_TIMELINE.
-- Consumes (v2.1 declared inputs): WRK_TRS_REL2_S5_PREP.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_REL2_S60_TIMELINE (

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

    -- ---- Step 60: TIMELINE (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_REL2_S6_TIMELINE AS
    WITH
    versions AS (
        SELECT p.*, p.dst_end_date AS tl_period_end_date FROM WRK_TRS_REL2_S5_PREP p
        UNION ALL
        SELECT p.*, NULL::TIMESTAMP_NTZ FROM WRK_TRS_REL2_S5_PREP p WHERE p.dst_end_date IS NOT NULL
    ),
    timeline AS (
        SELECT v.*,
               ROW_NUMBER() OVER (PARTITION BY v.pkey_src_object
                                  ORDER BY v.BEGIN_DT ASC NULLS LAST, v.tl_period_end_date DESC NULLS FIRST) AS tl_version_seq
          FROM versions v
    )
    SELECT t.*,
           IFF(t.tl_period_end_date IS NOT NULL, 2, NULL)                          AS tl_timeline_action,
           IFF(t.tl_period_end_date IS NULL AND t.tl_version_seq = 1, 1, NULL)     AS tl_hub_state_ind,
           /* BAD DATA: unique key (PKEY_SRC_OBJECT, VERSION_SEQ) not yet in the table */
           xr.PKEY_SRC_OBJECT IS NULL                                               AS uq_rel
      FROM timeline t
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT, VERSION_SEQ FROM C_S_TRS_PTY_RLE_REL_PROV) xr
             ON xr.PKEY_SRC_OBJECT = t.pkey_src_object AND xr.VERSION_SEQ = t.tl_version_seq;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_REL2_S6_TIMELINE;
    RETURN :l_rows;
END;$$;
