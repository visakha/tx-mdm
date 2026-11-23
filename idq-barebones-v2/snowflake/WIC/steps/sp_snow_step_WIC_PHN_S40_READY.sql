-- ============================================================================
-- sp_snow_step_WIC_PHN_S40_READY  --  BARE-BONES STEP DRIVER VARIANT (WIC)
--
-- Mapping: m_Tgt_C_S_WIC_Pty_Rle_Phn_And_EAddr, workflow wf_WIC_Stage_Load.
-- Step 40: READY.
-- Produces: WRK_WIC_PHN_S40_READY -- Run constants (phone type Telephone, usage 001, preference Primary, e-mail type 001, status Active, valid Y) and the insert-only guards (uq_phn, uq_eaddr, uq_phone_exc, uq_email_exc). Target guards evaluated here, before publish, as in the original single query.
-- Consumes: WRK_WIC_PHN_S30_ROUTED
--
-- Bare-bones variant: stripped of config gating, job tracking and
-- input checks; the CTAS below is unchanged business SQL. The driver
-- passes the run timestamp; steps that do not use it still declare it
-- so every step call has the same shape.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_step_WIC_PHN_S40_READY (
    P_RUN_TS                 TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    l_rows NUMBER DEFAULT 0;
BEGIN
    CREATE OR REPLACE TRANSIENT TABLE WRK_WIC_PHN_S40_READY AS
    SELECT r.*,
           '1' /* TIMELINE: VERSION_SEQ */                          AS version_seq,
           1                                                         AS hub_state_ind,
           'WIC'                                                     AS src_sys,
           :P_RUN_TS                                                 AS run_ts,
           :c_mapping                                                AS mapping_name,
           'Telephone'                                               AS phn_tp,
           '001'                                                     AS usg_tp,
           'Primary'                                                 AS pref_lvl,
           'Bad Value'                                               AS exc_type_bad_value,
           'Main Phone'                                              AS attr_phone,
           'Email'                                                   AS attr_email,
           '001'                                                     AS eaddr_addr_tp,
           'Active'                                                  AS eaddr_sts_cd,
           'Y'                                                       AS eaddr_is_vld,
           /* BAD DATA: unique keys Snowflake does not enforce */
           (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_good, r.phn_pkey ORDER BY r.DATEKEY DESC, r.FID) = 1
            AND xph.PKEY_SRC_OBJECT IS NULL)                         AS uq_phn,
           (ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.eaddr_pkey ORDER BY r.DATEKEY DESC, r.FID) = 1
            AND xea.PKEY_SRC_OBJECT IS NULL)                         AS uq_eaddr,
           ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.PTY_SRC_KEY, r.FID, r.phone_exception_code
                                  ORDER BY r.DATEKEY DESC) = 1       AS uq_phone_exc,
           ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.PTY_SRC_KEY, r.FID, r.email_exception_type,
                                           r.email_exception_code ORDER BY r.DATEKEY DESC) = 1 AS uq_email_exc
      FROM WRK_WIC_PHN_S30_ROUTED r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
             ON xph.PKEY_SRC_OBJECT = r.phn_pkey
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_WIC_PTY_RLE_EADDR WHERE VERSION_SEQ = 1) xea
             ON xea.PKEY_SRC_OBJECT = r.eaddr_pkey;;
    SELECT COUNT(*) INTO :l_rows FROM WRK_WIC_PHN_S40_READY;
    RETURN :l_rows;
END;
$$;
