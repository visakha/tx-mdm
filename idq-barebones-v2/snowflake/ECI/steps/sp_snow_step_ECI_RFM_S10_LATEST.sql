-- sp_snow_step_ECI_RFM_S10_LATEST -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid, workflow wf_ECI_Stage_Load, step 10 (LATEST_HISTORY_ROWS).
-- Produces: WRK_ECI_RFM_S10_LATEST.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_RFM_S10_LATEST (
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
    -- ---- Step 10: LATEST HISTORY ROWS + LOOKUP (verbatim CTAS) ---------
    CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_RFM_S10_LATEST AS
    SELECT h.*, d.ID_MEDICAID AS LKP_ID_MEDICAID
      FROM STG_ECI_H_MEDICAID h
     INNER JOIN (SELECT m.ID_MEDICAID, MAX(m.LOAD_DATE) AS MAX_LOAD_DATE
                   FROM STG_ECI_H_MEDICAID m
                  INNER JOIN STG_ECI_SN_CASE c ON m.ID_CASE = c.ID_CASE
                  WHERE c.ID_CHILD IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_CHILD')
                  GROUP BY m.ID_MEDICAID) mx
             ON mx.ID_MEDICAID = h.ID_MEDICAID AND mx.MAX_LOAD_DATE = h.LOAD_DATE
      LEFT JOIN (SELECT DISTINCT ID_MEDICAID FROM STG_ECI_D_MEDICAID) d ON d.ID_MEDICAID = h.ID_MEDICAID;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_RFM_S10_LATEST;
    RETURN :l_rows;
END;
$$;
