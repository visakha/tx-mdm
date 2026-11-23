-- ============================================================================
-- sp_snow_step_TRS_REL1_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_1_Mem_To_Mem, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SRC_RELATIONSHIPS. Produces: WRK_TRS_REL1_S1_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: P_INDV_ID_ALT_ID_TP; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_REL1_S10_SRC (

    P_INDV_ID_ALT_ID_TP VARCHAR DEFAULT '007',
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

    -- ---- Step 10: SRC_RELATIONSHIPS (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_REL1_S1_SRC AS
    WITH
    min_pk AS (
        SELECT indv_id, MIN(pty_pk) pty_pk FROM STG_TRS_VALID_MEMBERS GROUP BY indv_id
    )
    SELECT rel.indv_id AS INDV_ID, rel.ref_indv_id AS REF_INDV_ID, rel.eff_begin_dt AS EFF_BEGIN_DT,
           rel.eff_end_dt AS EFF_END_DT, rel.hist_nav_ind AS HIST_NAV_IND,
           rel.relationship_type_cd AS RELATIONSHIP_TYPE_CD, pk1.pty_pk AS PTY_PKEY, pk2.pty_pk AS REF_PTY_PKEY,
           :P_INDV_ID_ALT_ID_TP AS PTY_ALT_ID_TP, rel.create_dt AS CREATE_DT, rel.update_dt AS UPDATE_DT
      FROM STG_TRS_D_DC_RELATIONSHIPS rel
      JOIN min_pk pk1 ON rel.indv_id = pk1.indv_id
      JOIN min_pk pk2 ON rel.ref_indv_id = pk2.indv_id;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_REL1_S1_SRC;
    RETURN :l_rows;
END;$$;
