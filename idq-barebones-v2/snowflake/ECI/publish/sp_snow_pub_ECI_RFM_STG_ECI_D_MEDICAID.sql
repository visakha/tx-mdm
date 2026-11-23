-- sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Medicaid, workflow wf_ECI_Stage_Load, publish step 30 (PUBLISH_STG_ECI_D_MEDICAID).
-- Target: STG_ECI_D_MEDICAID. Consumes: WRK_ECI_RFM_S20_KEEPNEW.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- ---- Step 30: PUBLISH -- the original INSERT, verbatim --------------
    INSERT INTO STG_ECI_D_MEDICAID
           (ID_MEDICAID, ID_CASE, MEDICAID_NBR, ELIG_DATE, END_DATE, CURRENT_IND, CANCEL_DATE, HMO_DESC,
            DATE_CREATED, DATE_MODIFIED, MODIFIED_BY, CREATED_BY, CONSENT_TO_BILL, LOAD_DATE)
    SELECT h.ID_MEDICAID, h.ID_CASE, h.MEDICAID_NBR, h.ELIG_DATE, h.END_DATE, h.CURRENT_IND, h.CANCEL_DATE,
           h.HMO_DESC, h.DATE_CREATED, h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.CONSENT_TO_BILL, h.LOAD_DATE
      FROM WRK_ECI_RFM_S20_KEEPNEW h;
    RETURN SQLROWCOUNT;
END;
$$;
