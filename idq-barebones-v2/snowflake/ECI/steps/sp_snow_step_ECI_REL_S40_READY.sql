-- sp_snow_step_ECI_REL_S40_READY -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Rel, workflow wf_ECI_Stage_Load, step 40 (READY_TO_PUBLISH).
-- Produces: WRK_ECI_REL_S40_READY.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_REL_S40_READY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping  VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Rle_Rel';
    l_rows     NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 40: READY -- keys, exception details, guards (verbatim from the main)
    -- Purpose: build the two role keys and the relationship record key,
    -- resolve the exception details, and apply the insert-only guards.
    -- Reads ONLY step 30. This is the original built CTE plus the final
    -- SELECT (including the target-table guard join, which still sees
    -- the pre-run state because nothing has been published yet).
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_REL_S40_READY AS
    WITH
    built AS (
        SELECT t.*,
               IFF(t.RELATION_DIRECTION = 'To Child', t.family_pty_src_key, t.child_pty_src_key) || '|Member'
                                                                                          AS rel_fk_1,
               IFF(t.RELATION_DIRECTION = 'To Child', t.child_pty_src_key, t.family_pty_src_key) || '|Member'
                                                                                          AS rel_fk_2,
               IFF(t.RELATION_DIRECTION = 'To Child', t.family_pty_src_key, t.child_pty_src_key) || '|Member|'
               || IFF(t.RELATION_DIRECTION = 'To Child', t.child_pty_src_key, t.family_pty_src_key) || '|Member|'
               || NVL(t.mstr_ref_code, '')                                               AS rel_src_key
          FROM WRK_ECI_REL_S30_TYPED t
    )
    SELECT b.*,
           1 /* TIMELINE: VERSION_SEQ */                  AS version_seq,
           1                                              AS hub_state_ind,
           'Member Relationship'                          AS rel_type_code,
           'Member'                                       AS hierarchy_code,
           'ECI'                                          AS src_sys,
           :P_RUN_TS                                      AS run_ts,
           :c_mapping                                     AS mapping_name,
           'FAMILY_CD'                                    AS attr_family_cd,
           ex.EXCEPTION_CODE                              AS exc_code,
           ex.EXCEPTION_DESC                              AS exc_desc,
           ex.EXCEPTION_TYPE                              AS exc_type,
           (ROW_NUMBER() OVER (PARTITION BY b.mstr_ref_code IS NULL, b.rel_src_key
                                   ORDER BY b.DATE_MODIFIED DESC, b.ID_FAMILY) = 1
            AND xr.PKEY_SRC_OBJECT IS NULL)               AS uq_rel,
           ROW_NUMBER() OVER (PARTITION BY b.mstr_ref_code IS NULL, b.ID_FAMILY, b.ID_CHILD, b.rel_src_key
                                  ORDER BY b.DATE_MODIFIED DESC) = 1 AS uq_rel_exc
      FROM built b
      LEFT JOIN (SELECT * FROM TABLE(fn_snow_helper40_common())) ex ON ex.EXCEPTION_CODE = 'Invalid_Relationship'
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_REL WHERE VERSION_SEQ = 1) xr
             ON xr.PKEY_SRC_OBJECT = b.rel_src_key;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_REL_S40_READY;
    RETURN :l_rows;
END;
$$;
