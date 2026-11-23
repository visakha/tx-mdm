-- ----------------------------------------------------------------------------
-- run_wf_WIC_Stage_Load.sql
--
-- SnowSQL entry point for the bare-bones variant of wf_WIC_Stage_Load.
-- This REPLACES the original run script's 5 CALL lines with one runner
-- CALL. If your scheduler / CLI parses the old script looking for one
-- "CALL sp_snow_main_<mapping>();" per line, it must be updated to this
-- single runner CALL (see the User Guide, "Migrating the scheduler").
-- The IDQ command task (touch <workflow>.ind) is still left to the
-- scheduler, exactly as before.
--
-- SnowSQL:  snowsql -c <connection> -f run_wf_WIC_Stage_Load.sql
--
-- Restarting: just run this script again. There is no step-level
-- restart -- each mapping cleans up the previous run's WRK tables at its
-- start (step 5) and runs every step from scratch. A restart is always a
-- new run, and the runner RETURNs the combined summary string.
-- ----------------------------------------------------------------------------
!set exit_on_error=true

CALL sp_etl_run_wf_WIC_Stage_Load();
