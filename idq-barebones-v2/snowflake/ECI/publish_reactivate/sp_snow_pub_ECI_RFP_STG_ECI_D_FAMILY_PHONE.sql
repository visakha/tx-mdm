-- ============================================================================
-- sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE.sql -- PUBLISH_REACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_latest);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: NO
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_RFP_STG_ECI_D_FAMILY_PHONE ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 30: PUBLISH - INSERT verbatim from current main ---------
    -- The ONLY step that writes to a final target. No TRUNCATE, no
    -- DELETE: insert-only, as in the original Snowflake code.
INSERT INTO STG_ECI_D_FAMILY_PHONE
           (ID_FAMILY_PHONE, ID_FAMILY, ID_CASE, HOME_AC, HOME_NBR, WORK_AC, WORK_NBR, WORK_EXT, CELL_AC, CELL_NBR,
            FAX_AC, FAX_NBR, PAGER_AC, PAGER_NBR, OTHER_AC, OTHER_NBR, EMAIL_ADDRESS, DATE_CREATED, DATE_MODIFIED,
            MODIFIED_BY, CREATED_BY, CHILD_RESIDES_IND, INACTIVE_IND, PRIMARY_CONTACT_IND, LOAD_DATE)
    WITH
    s10_latest AS (
SELECT h.ID_FAMILY_PHONE, h.ID_FAMILY, h.ID_CASE, h.HOME_AC, h.HOME_NBR, h.WORK_AC, h.WORK_NBR, h.WORK_EXT, h.CELL_AC, h.CELL_NBR, h.FAX_AC, h.FAX_NBR, h.PAGER_AC, h.PAGER_NBR, h.OTHER_AC, h.OTHER_NBR, h.EMAIL_ADDRESS, h.DATE_CREATED, h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.CHILD_RESIDES_IND, h.INACTIVE_IND, h.PRIMARY_CONTACT_IND, h.LOAD_DATE
          FROM STG_ECI_H_FAMILY_PHONE h
         INNER JOIN (SELECT ID_FAMILY_PHONE, MAX(LOAD_DATE) AS MAX_LOAD_DATE
                       FROM STG_ECI_H_FAMILY_PHONE
                      WHERE ID_FAMILY IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_FAMILY')
                      GROUP BY ID_FAMILY_PHONE) m
                 ON m.ID_FAMILY_PHONE = h.ID_FAMILY_PHONE AND m.MAX_LOAD_DATE = h.LOAD_DATE
    )
    SELECT ID_FAMILY_PHONE AS ID_FAMILY_PHONE,
           ID_FAMILY AS ID_FAMILY,
           ID_CASE AS ID_CASE,
           HOME_AC AS HOME_AC,
           HOME_NBR AS HOME_NBR,
           WORK_AC AS WORK_AC,
           WORK_NBR AS WORK_NBR,
           WORK_EXT AS WORK_EXT,
           CELL_AC AS CELL_AC,
           CELL_NBR AS CELL_NBR,
           FAX_AC AS FAX_AC,
           FAX_NBR AS FAX_NBR,
           PAGER_AC AS PAGER_AC,
           PAGER_NBR AS PAGER_NBR,
           OTHER_AC AS OTHER_AC,
           OTHER_NBR AS OTHER_NBR,
           EMAIL_ADDRESS AS EMAIL_ADDRESS,
           DATE_CREATED AS DATE_CREATED,
           DATE_MODIFIED AS DATE_MODIFIED,
           MODIFIED_BY AS MODIFIED_BY,
           CREATED_BY AS CREATED_BY,
           CHILD_RESIDES_IND AS CHILD_RESIDES_IND,
           INACTIVE_IND AS INACTIVE_IND,
           PRIMARY_CONTACT_IND AS PRIMARY_CONTACT_IND,
           LOAD_DATE AS LOAD_DATE
      FROM s10_latest;

    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
