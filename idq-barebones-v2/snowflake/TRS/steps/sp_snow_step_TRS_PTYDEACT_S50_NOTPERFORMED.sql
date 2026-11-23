-- ============================================================================
-- sp_snow_step_TRS_PTYDEACT_S50_NOTPERFORMED  --  BARE-BONES STEP (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Deactivation_1, workflow wf_TRS_Stage_Load_1_Ongoing, step 50.
-- Step name: DELETE_VALID_STAGE_NOT_PERFORMED.
--
-- NO-DATA STEP -- IT WRITES NOTHING.
--   This step exists so that the IDQ behaviour this mapping does NOT
--   reproduce stays visible in the driver summary instead of buried in
--   a code comment. IDQ Delete_Valid_Stage (DD_DELETE) deletes the
--   deactivated members from STG_TRS_VALID_MEMBERS (key PTY_PK).
--   Snowflake does NOT perform it: this code base never deletes,
--   truncates or drops target rows (rows are only inserted), so
--   deactivated members stay in the valid-member list. Re-adding the
--   delete is a business decision, not a silent fix. This proc just
--   returns 0. It is called by the driver AFTER the publish transaction
--   has committed, because the original step order is publish (40) then
--   this record (50). It consumes no work table.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_TRS_PTYDEACT_S50_NOTPERFORMED (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- Its only v2.1 action was a removed completion call; the proc
    -- now just returns 0 and the driver records the step in its summary.
    RETURN 0;
END;
$$;
