-- ============================================================================
-- sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID.sql -- PUBLISH_REACTIVATE S10-only twin (STG_* status, first step only)
--
-- Twin of publish/sp_snow_pub_ECI_RFM_STG_ECI_D_MEDICAID.sql. Same procedure, same target, same column list
-- -- but ONLY the first (source) step is inlined as a CTE (s10_latest);
-- every later step and the WHERE gate are dropped. Each target column
-- is aliased from a first-step column, a literal, or a parameter
-- (see map). A column the first step does not carry is NULL (see map).
-- WHERE gate dropped: none (no gate in original)
-- P_RUN_TS: NO
-- ============================================================================
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
    WITH
    s10_latest AS (
SELECT h.ID_MEDICAID, h.ID_CASE, h.MEDICAID_NBR, h.ELIG_DATE, h.END_DATE, h.CURRENT_IND, h.CANCEL_DATE, h.HMO_DESC, h.DATE_CREATED, h.DATE_MODIFIED, h.MODIFIED_BY, h.CREATED_BY, h.CONSENT_TO_BILL, h.LOAD_DATE, d.ID_MEDICAID AS LKP_ID_MEDICAID
          FROM STG_ECI_H_MEDICAID h
         INNER JOIN (SELECT m.ID_MEDICAID, MAX(m.LOAD_DATE) AS MAX_LOAD_DATE
                       FROM STG_ECI_H_MEDICAID m
                      INNER JOIN STG_ECI_SN_CASE c ON m.ID_CASE = c.ID_CASE
                      WHERE c.ID_CHILD IN (SELECT ID FROM V_ECI_ETL_LU_REACTIVATED_ID WHERE ID_TYPE = 'ID_CHILD')
                      GROUP BY m.ID_MEDICAID) mx
                 ON mx.ID_MEDICAID = h.ID_MEDICAID AND mx.MAX_LOAD_DATE = h.LOAD_DATE
          LEFT JOIN (SELECT DISTINCT ID_MEDICAID FROM STG_ECI_D_MEDICAID) d ON d.ID_MEDICAID = h.ID_MEDICAID
    )
    SELECT ID_MEDICAID AS ID_MEDICAID,
           ID_CASE AS ID_CASE,
           MEDICAID_NBR AS MEDICAID_NBR,
           ELIG_DATE AS ELIG_DATE,
           END_DATE AS END_DATE,
           CURRENT_IND AS CURRENT_IND,
           CANCEL_DATE AS CANCEL_DATE,
           HMO_DESC AS HMO_DESC,
           DATE_CREATED AS DATE_CREATED,
           DATE_MODIFIED AS DATE_MODIFIED,
           MODIFIED_BY AS MODIFIED_BY,
           CREATED_BY AS CREATED_BY,
           CONSENT_TO_BILL AS CONSENT_TO_BILL,
           LOAD_DATE AS LOAD_DATE
      FROM s10_latest;

    RETURN SQLROWCOUNT;
END;
$$;
