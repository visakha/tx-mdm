-- sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Addr, workflow wf_ECI_Stage_Load, publish step 30 (PUBLISH_STG_ECI_D_FAMILY_ADDRESS).
-- Target: STG_ECI_D_FAMILY_ADDRESS. Consumes: WRK_ECI_RFA_S20_KEEPNEW.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows    NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: PUBLISH (verbatim from current main)
    INSERT INTO STG_ECI_D_FAMILY_ADDRESS
           (ID_FAMILY_ADDRESS, ID_FAMILY, ID_CASE, ADDRESS_CD, ADDRESS1, ADDRESS2, ID_ST_CITY_CNTY_ZIP, CITY_NAME,
            COUNTY_NAME, ZIP_CODE, ZIP_SFX, STATE_ABBREV, CANCEL_DATE, DATE_CREATED, DATE_MODIFIED, MODIFIED_BY,
            CREATED_BY, LOAD_DATE)
    SELECT h.ID_FAMILY_ADDRESS, h.ID_FAMILY, h.ID_CASE, h.ADDRESS_CD, h.ADDRESS1, h.ADDRESS2, h.ID_ST_CITY_CNTY_ZIP,
           h.CITY_NAME, h.COUNTY_NAME, h.ZIP_CODE, h.ZIP_SFX, h.STATE_ABBREV, h.CANCEL_DATE, h.DATE_CREATED,
           h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.LOAD_DATE
      FROM WRK_ECI_RFA_S20_KEEPNEW h;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
