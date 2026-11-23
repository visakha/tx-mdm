-- ============================================================================
-- sp_snow_step_TRS_RELDEACT_S40_XREF  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Rel_DeActivation_1, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: XREF_ONE. Produces: WRK_TRS_RELDEACT_S40_XREF.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_RELDEACT_S40_XREF (

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

    -- ---- Step 40: XREF_ONE (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_RELDEACT_S40_XREF AS
    WITH
    xref_obj AS (
        SELECT ROWID_OBJECT, COUNT(DISTINCT PKEY_SRC_OBJECT) AS SRC_PKEY_CT, MAX(HUB_STATE_IND) AS MAX_HUB_STATE_IND
          FROM C_B_PTY_RLE_REL_XREF
         GROUP BY ROWID_OBJECT
    ),
    xref_key AS (
        SELECT PKEY_SRC_OBJECT, MIN(ROWID_XREF) AS MIN_ROWID_XREF
          FROM C_B_PTY_RLE_REL_XREF
         GROUP BY PKEY_SRC_OBJECT
    ),
    xref AS (
        SELECT DISTINCT t.ROWID_OBJECT, t.PKEY_SRC_OBJECT, t.ROWID_SYSTEM, o.SRC_PKEY_CT,
               IFF(o.SRC_PKEY_CT > 1, 'Y', 'N')                          AS MERGE_YN,
               IFF(t.ROWID_OBJECT = t.ORIG_ROWID_OBJECT, 'Y', 'N')        AS MASTER_RECORD_YN,
               IFF(o.MAX_HUB_STATE_IND = -1, 'Y', 'N')                    AS SOFT_DELETE_YN,
               k.MIN_ROWID_XREF
          FROM C_B_PTY_RLE_REL_XREF t
          JOIN xref_obj o ON o.ROWID_OBJECT = t.ROWID_OBJECT
          JOIN xref_key k ON k.PKEY_SRC_OBJECT = t.PKEY_SRC_OBJECT
    )
    SELECT * FROM xref
    QUALIFY ROW_NUMBER() OVER (PARTITION BY PKEY_SRC_OBJECT ORDER BY ROWID_OBJECT) = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_RELDEACT_S40_XREF;
    RETURN :l_rows;
END;$$;
