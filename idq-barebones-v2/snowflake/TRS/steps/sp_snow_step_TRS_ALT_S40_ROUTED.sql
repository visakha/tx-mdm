-- ============================================================================
-- sp_snow_step_TRS_ALT_S40_ROUTED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Alt_Id, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: ROUTED. Produces: WRK_TRS_ALT_S4_ROUTED.
-- Consumes (v2.1 declared inputs): WRK_TRS_ALT_S3_NORM.
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ALT_S40_ROUTED (

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

    -- ---- Step 40: ROUTED (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ALT_S4_ROUTED AS
    WITH
    lkp_exc AS (SELECT * FROM TABLE(fn_snow_helper40_common())),
    lkp_lcv AS (SELECT * FROM TABLE(fn_snow_helper45_common())),
    routed AS (
        SELECT n.PKEY_SRC_OBJECT_PTY AS pkey_src_object_pty, n.PERIOD_START_DATE AS period_start_date,
               n.ALT_ID_VAL AS alt_id_val, lb.MSTR_REF_CODE AS alt_id_typ, lb.MSTR_REF_LABEL AS alt_id_label,
               n.DQ_EXCP_CD AS dq_excp_cd, xd.EXCEPTION_DESC AS dq_excp, n.SRC_SYS AS src_sys, n.CV_IND AS cv_ind,
               NVL(n.PKEY_SRC_OBJECT_PTY, '') || '|Member|' || NVL(lb.MSTR_REF_CODE, '') || '|' || n.ALT_ID_VAL
                                                                                     AS pkey_src_object_alt_id,
               NVL(n.PKEY_SRC_OBJECT_PTY, '') || '|Member'                           AS pty_rle_fk,
               /* VALIDATION */ fn_snow_helper03_common(n.DQ_EXCP_CD)                AS is_valid
          FROM WRK_TRS_ALT_S3_NORM n
          LEFT JOIN lkp_lcv lb ON lb.CODE_TYPE = 'ALT_ID_TP' AND lb.MSTR_REF_CODE = n.ALT_ID_TYP
                              AND lb.SRC_SYS = n.SRC_SYS
          LEFT JOIN lkp_exc xd ON xd.EXCEPTION_CODE = n.DQ_EXCP_CD
         /* BAD DATA: FLTR_Remove_Null_Alt_IDs: NOT ISNULL(ALT_ID_VAL) AND RTRIM(ALT_ID_VAL) <> '' */
         WHERE n.ALT_ID_VAL IS NOT NULL AND RTRIM(n.ALT_ID_VAL) <> ''
    )
    SELECT r.*,
           1 /* TIMELINE: exp_Rank.VERSION_SEQ hard-coded */                  AS version_seq,
           'Issued'                                                            AS sts_cd,
           'Bad Value'                                                         AS exc_type,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY r.is_valid, r.pkey_src_object_alt_id
                                   ORDER BY r.alt_id_typ NULLS LAST, r.period_start_date DESC) = 1
            AND xa.PKEY_SRC_OBJECT IS NULL)                                    AS uq_alt_id,
           ROW_NUMBER() OVER (PARTITION BY r.is_valid, r.pkey_src_object_pty, r.dq_excp_cd
                                  ORDER BY r.alt_id_typ NULLS LAST) = 1        AS uq_exc
      FROM routed r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_RLE_ALT_ID WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = r.pkey_src_object_alt_id;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ALT_S4_ROUTED;
    RETURN :l_rows;
END;$$;
