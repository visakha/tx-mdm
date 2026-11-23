-- sp_snow_step_ECI_ALT_S40_READY -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Alt_Id, workflow wf_ECI_Stage_Load, step 40 (READY_TO_PUBLISH).
-- Produces: WRK_ECI_ALT_S40_READY.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_ALT_S40_READY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Rle_Alt_Id';
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 40: READY -- guards (verbatim from current main)
    -- Purpose: the publish-ready rows with the insert-only guards
    -- (key not yet in the target, first row per key in this run; for
    -- SSN exceptions, key not already logged with a NULL run date).
    -- Reads ONLY step 30. This is the original final SELECT (including
    -- the target-table guard joins, which still see the pre-run state
    -- because nothing has been published yet).
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_ALT_S40_READY AS
    SELECT r.*,
           TO_VARCHAR(r.ID) || '|' || r.ALT_ID_TP                    AS src_rowid,
           1 /* TIMELINE: VERSION_SEQ */                             AS version_seq,
           'Issued'                                                  AS sts_cd,
           1                                                         AS hub_state_ind,
           NVL(r.DATE_MODIFIED, r.DATE_CREATED)                      AS src_last_upd_dt,
           'ECI'                                                     AS src_sys,
           :P_RUN_TS                                                 AS run_ts,
           :c_mapping                                                AS mapping_name,
           'ALT_ID_Type_SSN'                                         AS attr_ssn,
           'ALT_ID_TP_MedicaidId'                                    AS attr_medicaid,
           (ROW_NUMBER() OVER (PARTITION BY r.grp_valid, r.PKEY_SRC_OBJECT ORDER BY r.DATE_MODIFIED DESC, r.ID) = 1
            AND xa.PKEY_SRC_OBJECT IS NULL)                          AS uq_alt_id,
           (ROW_NUMBER() OVER (PARTITION BY r.grp_ssn_exc, r.PKEY_SRC_OBJECT, r.PTY_REL_FK, r.ssn_lkp_type,
                                            r.ssn_lkp_code ORDER BY r.ID) = 1
            AND xe.SRC_SYS_ID_1 IS NULL)                             AS uq_ssn_exc,
           ROW_NUMBER() OVER (PARTITION BY r.grp_mcd_exc, r.PKEY_SRC_OBJECT, r.PTY_REL_FK,
                                           r.medicaid_exception_type, r.medicaid_exception_code
                                  ORDER BY r.ID) = 1                 AS uq_mcd_exc
      FROM WRK_ECI_ALT_S30_ROUTED r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = r.PKEY_SRC_OBJECT
      LEFT JOIN (SELECT DISTINCT SRC_SYS_ID_1, SRC_SYS_ID_2, NVL(EXCEPTION_TYPE, '~') AS EXC_TYPE,
                        NVL(EXCEPTION_CODE, '~') AS EXC_CODE
                   FROM EXC_STG_BAD_REC_MEMB
                  WHERE SRC_SYS = 'ECI' AND RUN_DATE IS NULL AND SRC_SYS_ID_3 IS NULL) xe
             ON r.grp_ssn_exc AND xe.SRC_SYS_ID_1 = r.PKEY_SRC_OBJECT AND xe.SRC_SYS_ID_2 = r.PTY_REL_FK
            AND xe.EXC_TYPE = NVL(r.ssn_lkp_type, '~') AND xe.EXC_CODE = NVL(r.ssn_lkp_code, '~');
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_ALT_S40_READY;
    RETURN :l_rows;
END;
$$;
