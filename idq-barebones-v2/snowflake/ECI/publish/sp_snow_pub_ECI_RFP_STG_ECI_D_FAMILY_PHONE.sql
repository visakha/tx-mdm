-- sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_Stg_ECI_Pty_Reactivation_D_Family_Phn, workflow wf_ECI_Stage_Load, publish step 30 (PUBLISH_STG_ECI_D_FAMILY_PHONE).
-- Target: STG_ECI_D_FAMILY_PHONE. Consumes: WRK_ECI_RFP_S20_KEEPNEW.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: PUBLISH — INSERT verbatim from current main ---------
    -- The ONLY step that writes to a final target. No TRUNCATE, no
    -- DELETE: insert-only, as in the original Snowflake code.
    INSERT INTO STG_ECI_D_FAMILY_PHONE
           (ID_FAMILY_PHONE, ID_FAMILY, ID_CASE, HOME_AC, HOME_NBR, WORK_AC, WORK_NBR, WORK_EXT, CELL_AC, CELL_NBR,
            FAX_AC, FAX_NBR, PAGER_AC, PAGER_NBR, OTHER_AC, OTHER_NBR, EMAIL_ADDRESS, DATE_CREATED, DATE_MODIFIED,
            MODIFIED_BY, CREATED_BY, CHILD_RESIDES_IND, INACTIVE_IND, PRIMARY_CONTACT_IND, LOAD_DATE)
    SELECT h.ID_FAMILY_PHONE, h.ID_FAMILY, h.ID_CASE, h.HOME_AC, h.HOME_NBR, h.WORK_AC, h.WORK_NBR, h.WORK_EXT,
           h.CELL_AC, h.CELL_NBR, h.FAX_AC, h.FAX_NBR, h.PAGER_AC, h.PAGER_NBR, h.OTHER_AC, h.OTHER_NBR,
           h.EMAIL_ADDRESS, h.DATE_CREATED, h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.CHILD_RESIDES_IND,
           h.INACTIVE_IND, h.PRIMARY_CONTACT_IND, h.LOAD_DATE
      FROM WRK_ECI_RFP_S20_KEEPNEW h;
    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
