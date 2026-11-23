-- sp_snow_step_ECI_REL_S30_TYPED -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Rel, workflow wf_ECI_Stage_Load, step 30 (CODED_TRANSLATED).
-- Produces: WRK_ECI_REL_S30_TYPED.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_REL_S30_TYPED (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows     NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: RELATIONSHIP CODE + TRANSLATION (verbatim from the main)
    -- Purpose: build the relationship code (family code alone for the
    -- family-to-child direction; family code plus child gender for the
    -- reverse direction) and translate it in the code-value table.
    -- Reads ONLY step 20. This is the original coded + typed CTEs.
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_REL_S30_TYPED AS
    WITH
    coded AS (
        SELECT k.*,
               IFF(k.RELATION_DIRECTION = 'To Child', TO_VARCHAR(k.FAMILY_CD),
                   NVL(TO_VARCHAR(k.FAMILY_CD), '') || '|' || NVL(ch.GENDER, ''))     AS rel_family_cd
          FROM WRK_ECI_REL_S20_KEYED k
          LEFT JOIN (SELECT c.ID_CHILD, c.GENDER FROM STG_ECI_SN_CHILD c
                     QUALIFY ROW_NUMBER() OVER (PARTITION BY c.ID_CHILD ORDER BY c.GENDER) = 1) ch
                 ON ch.ID_CHILD = k.ID_CHILD
    )
    SELECT c.*, lk.MSTR_REF_CODE AS mstr_ref_code
      FROM coded c
      LEFT JOIN (SELECT l.SRC_CODE_VALUE, l.MSTR_REF_CODE FROM LOOKUP_CODE_VALUE l
                  WHERE l.CODE_TYPE IN ('REL_TP', 'INVERSE_REL') AND l.SRC_SYS = 'ECI'
                QUALIFY ROW_NUMBER() OVER (PARTITION BY l.SRC_CODE_VALUE ORDER BY l.CODE_TYPE DESC,
                                           l.MSTR_REF_CODE) = 1) lk
             ON lk.SRC_CODE_VALUE = c.rel_family_cd;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_REL_S30_TYPED;
    RETURN :l_rows;
END;
$$;
