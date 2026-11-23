-- ============================================================================
-- sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS.sql -- PUBLISH_REACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_RFA_STG_ECI_D_FAMILY_ADDRESS.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_latest);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: NO
-- ============================================================================
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
    WITH
    s10_latest AS (
SELECT h.ID_FAMILY_ADDRESS, h.ID_FAMILY, h.ID_CASE, h.ADDRESS_CD, h.ADDRESS1, h.ADDRESS2, h.ID_ST_CITY_CNTY_ZIP, h.CITY_NAME, h.COUNTY_NAME, h.ZIP_CODE, h.ZIP_SFX, h.STATE_ABBREV, h.CANCEL_DATE, h.DATE_CREATED, h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.LOAD_DATE
          FROM STG_ECI_H_FAMILY_ADDRESS h
         INNER JOIN (SELECT ID_FAMILY_ADDRESS, MAX(LOAD_DATE) AS MAX_LOAD_DATE
                       FROM STG_ECI_H_FAMILY_ADDRESS
                      WHERE ID_FAMILY IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_FAMILY')
                      GROUP BY ID_FAMILY_ADDRESS) m
                 ON m.ID_FAMILY_ADDRESS = h.ID_FAMILY_ADDRESS AND m.MAX_LOAD_DATE = h.LOAD_DATE
    )
    SELECT ID_FAMILY_ADDRESS AS ID_FAMILY_ADDRESS,
           ID_FAMILY AS ID_FAMILY,
           ID_CASE AS ID_CASE,
           ADDRESS_CD AS ADDRESS_CD,
           ADDRESS1 AS ADDRESS1,
           ADDRESS2 AS ADDRESS2,
           ID_ST_CITY_CNTY_ZIP AS ID_ST_CITY_CNTY_ZIP,
           CITY_NAME AS CITY_NAME,
           COUNTY_NAME AS COUNTY_NAME,
           ZIP_CODE AS ZIP_CODE,
           ZIP_SFX AS ZIP_SFX,
           STATE_ABBREV AS STATE_ABBREV,
           CANCEL_DATE AS CANCEL_DATE,
           DATE_CREATED AS DATE_CREATED,
           DATE_MODIFIED AS DATE_MODIFIED,
           MODIFIED_BY AS MODIFIED_BY,
           CREATED_BY AS CREATED_BY,
           LOAD_DATE AS LOAD_DATE
      FROM s10_latest;

    l_rows := SQLROWCOUNT;
    RETURN :l_rows;
END;
$$;
