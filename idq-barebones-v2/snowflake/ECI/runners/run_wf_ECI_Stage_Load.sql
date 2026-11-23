-- ----------------------------------------------------------------------------
-- run_wf_ECI_Stage_Load.sql -- BARE-BONES variant (ECI)
--
-- SnowSQL entry point for the bare-bones variant of wf_ECI_Stage_Load.
-- One runner CALL runs all 9 mappings in order. The runner RETURNs the
-- combined summary string.
--
-- SnowSQL:  snowsql -c <connection> -f run_wf_ECI_Stage_Load.sql
--
-- Restarting: just run this script again. Each mapping cleans up the
-- previous run's work tables at its start (step 5) and runs every step
-- from scratch. Work tables are left standing at the end of a run.
-- ----------------------------------------------------------------------------
!set exit_on_error=true

CALL sp_etl_run_wf_ECI_Stage_Load();
