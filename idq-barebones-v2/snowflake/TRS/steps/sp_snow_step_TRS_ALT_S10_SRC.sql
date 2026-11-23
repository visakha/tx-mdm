-- ============================================================================
-- sp_snow_step_TRS_ALT_S10_SRC  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Rle_Alt_Id, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Step name: SRC_DEDUP. Produces: WRK_TRS_ALT_S1_SRC.
-- Consumes (v2.1 declared inputs): (base tables only).
-- Original params used: none; plus P_RUN_TS (run timestamp).
--
-- The CTAS below is the v2.1 step SELECT verbatim. The only removals
-- were the work-table existence check and the step completion call.
-- No exception block (errors propagate to the driver handler), no
-- transactions, no target writes. Returns the row count.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_ALT_S10_SRC (

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

    -- ---- Step 10: SRC_DEDUP (verbatim from current main)
CREATE OR REPLACE TRANSIENT TABLE WRK_TRS_ALT_S1_SRC AS
    WITH
    all_indv AS (
        SELECT DISTINCT TO_VARCHAR(mci_indv.indv_id) AS pty_pkey, mci_indv.indv_id AS member_id,
               mci_indv.create_dt, mci_indv.ssn, '1' AS cv_ind
          FROM STG_TRS_D_CV_DC_MCI_INDV mci_indv
        UNION ALL
        SELECT DISTINCT TO_VARCHAR(indv.indv_id) || '|DC_INDV', indv.indv_id, indv.create_dt, indv.ssn, NULL
          FROM STG_TRS_D_DC_INDV indv
        UNION ALL
        SELECT DISTINCT TO_VARCHAR(mrg.old_indv_id), mrg.indv_id, mrg.create_dt, NULL, NULL
          FROM STG_TRS_D_CV_DC_MRG_SPRT_INDV mrg
         WHERE mrg.type_cd = 'ME'
    ),
    de_dup_indv AS (
        SELECT a.pty_pkey, TO_VARCHAR(a.member_id) AS member_id, a.create_dt AS start_dt, a.ssn, a.cv_ind,
               ROW_NUMBER() OVER (PARTITION BY a.pty_pkey
                                  ORDER BY LENGTH(TO_VARCHAR(a.ssn)) DESC NULLS LAST, a.create_dt DESC) AS key_rn
          FROM all_indv a
          JOIN STG_TRS_VALID_MEMBERS vm ON a.pty_pkey = vm.pty_pk
    )
    SELECT pty_pkey AS PTY_PKEY, member_id AS MEMBER_ID, start_dt AS START_DT, ssn AS SSN, cv_ind AS CV_IND
      FROM de_dup_indv
     WHERE key_rn = 1;
    SELECT COUNT(*) INTO :l_rows FROM WRK_TRS_ALT_S1_SRC;
    RETURN :l_rows;
END;$$;
