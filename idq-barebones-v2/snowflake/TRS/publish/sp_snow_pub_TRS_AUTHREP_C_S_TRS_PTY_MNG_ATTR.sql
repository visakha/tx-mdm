-- ============================================================================
-- sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Auth_Rep_Ongoing, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_MNG_ATTR. Kind: SPINE (Authorised representative flags).
-- Consumes (v2.1 declared inputs): WRK_TRS_MNGAR_S40_AGG.
-- Keeps P_RUN_TS: Y. Original params used: P_ATTR_TP_AUTH_REP.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_AUTHREP_C_S_TRS_PTY_MNG_ATTR (

    P_ATTR_TP_AUTH_REP VARCHAR DEFAULT 'Auth_Rep_Flag',
    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_MNG_ATTR
           (CREATE_DATE, LAST_UPDATE_DATE, MNG_ATTR_TP, PTY_FK, PERIOD_END_DATE, PERIOD_START_DATE, VERSION_SEQ,
            SRC_ROWID, PKEY_SRC_OBJECT, SRC_LAST_UPD_DT, MNG_ATTR_VAL)
    SELECT g.CREATE_DT, :P_RUN_TS, :P_ATTR_TP_AUTH_REP, g.pty_pk, g.max_eff_end_dt,
           g.EFF_BEGIN_DT, 1, g.pkey_src_object,
           g.pkey_src_object, g.CREATE_DT, g.AR_FLAG
      FROM WRK_TRS_MNGAR_S40_AGG g
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_MNG_ATTR WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = g.pkey_src_object
     WHERE g.rn = 1
       AND xa.PKEY_SRC_OBJECT IS NULL;
    RETURN SQLROWCOUNT;
END;
$$;
