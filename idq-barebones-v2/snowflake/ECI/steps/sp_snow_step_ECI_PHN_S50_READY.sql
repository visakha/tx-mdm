-- sp_snow_step_ECI_PHN_S50_READY -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr, workflow wf_ECI_Stage_Load, step 50 (READY_TO_PUBLISH).
-- Produces: WRK_ECI_PHN_S50_READY.
-- Runs unconditionally from the driver; no gating, no checkpointing.
-- Business SQL below is verbatim from the v2.1 step procedure.
CREATE OR REPLACE PROCEDURE sp_snow_step_ECI_PHN_S50_READY (
    P_RUN_TS TIMESTAMP_NTZ
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    c_mapping    VARCHAR DEFAULT 'm_Tgt_C_S_ECI_Pty_Rle_Phn_And_EAddr';
    l_rows       NUMBER DEFAULT 0;
BEGIN
    -- ---- Step 50 CTAS (verbatim from the original main procedure) ----
CREATE OR REPLACE TRANSIENT TABLE WRK_ECI_PHN_S50_READY AS
    SELECT r.*,
           '1' /* TIMELINE: VERSION_SEQ */                                     AS version_seq,
           1                                                                    AS hub_state_ind,
           'ECI'                                                                AS src_sys,
           :P_RUN_TS                                                            AS run_ts,
           :c_mapping                                                           AS mapping_name,
           'Bad Value'                                                          AS exc_type_bad_value,
           IFF(r.PREF_LVL = 'Primary', r.std_phone, NULL)                       AS exc_primary_phone,
           IFF(r.USG_TP = 'Work', r.std_phone, NULL)                            AS exc_work_phone,
           IFF(r.PREF_LVL = 'Secondary', r.std_phone, NULL)                     AS exc_secondary_phone,
           DECODE(r.USG_TP, '001', 'Main Phone', '002', 'Work Phone', '003', 'Other Phone') AS exc_phone_attribute,
           'Email'                                                              AS exc_email_attribute,
           '001'                                                                AS eaddr_addr_tp,
           'Active'                                                             AS eaddr_sts_cd,
           'Y'                                                                  AS eaddr_is_vld,
           (ROW_NUMBER() OVER (PARTITION BY r.grp_phone_good, r.pkey_src_object
                                   ORDER BY r.PERIOD_START_DATE DESC, r.ID_FAMILY_PHONE) = 1
            AND xph.PKEY_SRC_OBJECT IS NULL)                                    AS uq_phn,
           (ROW_NUMBER() OVER (PARTITION BY r.grp_email_good, r.pkey_src_object
                                   ORDER BY r.PERIOD_START_DATE DESC, r.ID_FAMILY_PHONE) = 1
            AND xea.PKEY_SRC_OBJECT IS NULL)                                    AS uq_eaddr,
           ROW_NUMBER() OVER (PARTITION BY r.grp_phone_bad, r.ID_CASE, r.USG_TP, r.phone_exception_code
                                  ORDER BY r.ID_FAMILY_PHONE) = 1               AS uq_phone_exc,
           ROW_NUMBER() OVER (PARTITION BY r.grp_email_bad, r.ID_FAMILY_PHONE, r.email_exception_type,
                                           r.email_exception_code ORDER BY r.ID) = 1 AS uq_email_exc
      FROM WRK_ECI_PHN_S40_ROUTED r
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_PHN WHERE VERSION_SEQ = 1) xph
             ON xph.PKEY_SRC_OBJECT = r.pkey_src_object
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_ECI_PTY_RLE_EADDR WHERE VERSION_SEQ = 1) xea
             ON xea.PKEY_SRC_OBJECT = r.pkey_src_object;
    SELECT COUNT(*) INTO :l_rows FROM WRK_ECI_PHN_S50_READY;
    RETURN :l_rows;
END;
$$;
