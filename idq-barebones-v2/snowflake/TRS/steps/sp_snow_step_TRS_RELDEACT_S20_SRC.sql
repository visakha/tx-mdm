-- ============================================================================
-- sp_snow_step_TRS_RELDEACT_S20_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: REL_SRC. Produces: WRK_TRS_RELDEACT_S20_SRC.
-- Consumes (v2.1 declared inputs): WRK_TRS_RELDEACT_S10_MINPK.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_RELDEACT_S20_SRC (

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

    -- ---- Step 20: REL_SRC (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_RELDEACT_S20_SRC AS
    SELECT rel.indv_id AS INDV_ID, rel.ref_indv_id AS REF_INDV_ID, rel.eff_begin_dt AS EFF_BEGIN_DT,
           rel.eff_end_dt AS EFF_END_DT, rel.relationship_type_cd AS RELATIONSHIP_TYPE_CD, pk1.pty_pk AS PTY_PKEY,
           pk2.pty_pk AS REF_PTY_PKEY, 'TRS' AS SRC_SYS
      FROM STG_TRS_D_DC_RELATIONSHIPS_A rel
      JOIN WRK_TRS_RELDEACT_S10_MINPK pk1 ON rel.indv_id = pk1.indv_id
      JOIN WRK_TRS_RELDEACT_S10_MINPK pk2 ON rel.ref_indv_id = pk2.indv_id;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_RELDEACT_S20_SRC;
    RETURN :l_rows;
END;$$;
