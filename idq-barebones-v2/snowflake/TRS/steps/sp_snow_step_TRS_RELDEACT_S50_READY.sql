-- ============================================================================
-- sp_snow_step_TRS_RELDEACT_S50_READY  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: READY_TO_PUBLISH. Produces: WRK_TRS_RELDEACT_S50_READY.
-- Consumes (v2.1 declared inputs): WRK_TRS_RELDEACT_S30_KEYED|WRK_TRS_RELDEACT_S40_XREF.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_RELDEACT_S50_READY (

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

    -- ---- Step 50: READY_TO_PUBLISH (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_RELDEACT_S50_READY AS
    SELECT k.INDV_ID AS INDV_ID, k.REF_INDV_ID AS REF_INDV_ID,
           k.pty_rle_fk_1 AS PTY_RLE_FK_1, k.pty_rle_fk_2 AS PTY_RLE_FK_2,
           k.RELATIONSHIP_TYPE_CD AS REL_TYPE_CODE, x.SRC_PKEY_CT AS SRC_PKEY_CT,
           :P_RUN_TS AS LOAD_DATE, k.pkey_src_object AS PKEY_SRC_OBJECT,
           x.ROWID_OBJECT AS ROWID_OBJECT, x.MASTER_RECORD_YN AS MASTER_RECORD_YN,
           TRIM(x.MERGE_YN) AS MERGED_YN, k.SRC_SYS AS ROWID_SYSTEM, x.MIN_ROWID_XREF AS ROWID_XREF
      FROM WRK_TRS_RELDEACT_S30_KEYED k
      LEFT JOIN WRK_TRS_RELDEACT_S40_XREF x ON x.PKEY_SRC_OBJECT = k.pkey_src_object
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM STG_TRS_DEACTIVATED_RELATIONSHIPS
                  WHERE PROCESSED_YN = 'N' AND PKEY_SRC_OBJECT IS NOT NULL) d
             ON d.PKEY_SRC_OBJECT = k.pkey_src_object
     WHERE d.PKEY_SRC_OBJECT IS NULL
       AND x.MIN_ROWID_XREF IS NOT NULL;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_RELDEACT_S50_READY;
    RETURN :l_rows;
END;$$;
