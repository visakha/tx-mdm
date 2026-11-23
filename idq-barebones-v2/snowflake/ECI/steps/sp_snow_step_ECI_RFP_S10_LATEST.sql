-- sp_snow_step_ECI_RFP_S10_LATEST -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn, workflow wf_ECI_Stage_Load, step 10 (LATEST_HISTORY_ROWS).
-- Produces: WRK_ECI_RFP_S10_LATEST.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_RFP_S10_LATEST (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 10: LATEST HISTORY ROWS (CTAS verbatim from current main) --
    -- Purpose: the latest-load history row of each phone record
    -- belonging to a reactivated family. This is the history-to-latest
    -- join of the original INSERT (the source filter).
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_RFP_S10_LATEST AS
    SELECT h.*
      FROM STG_ECI_H_FAMILY_PHONE h
     INNER JOIN (SELECT ID_FAMILY_PHONE, MAX(LOAD_DATE) AS MAX_LOAD_DATE
                   FROM STG_ECI_H_FAMILY_PHONE
                  WHERE ID_FAMILY IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_FAMILY')
                  GROUP BY ID_FAMILY_PHONE) m
             ON m.ID_FAMILY_PHONE = h.ID_FAMILY_PHONE AND m.MAX_LOAD_DATE = h.LOAD_DATE;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_RFP_S10_LATEST;
    RETURN :l_rows;
END;
$$;
