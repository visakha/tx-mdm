-- ============================================================================
-- sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR  --  BARE-BONES PUBLISH BRANCH (TRS)
--
-- Mapping: m_Tgt_C_S_TRS_Pty_Mng_Attr_Sw, workflow wf_TRS_Stage_Load_1_Ongoing.
-- Target: C_S_TRS_PTY_MNG_ATTR. Kind: SPINE (Switch attributes).
-- Consumes (v2.1 declared inputs): WRK_TRS_MNGSW_S40_ATTRS.
-- Keeps P_RUN_TS: Y. Original params used: none.
--
-- The INSERT below is the v2.1 branch INSERT verbatim. NO transaction
-- control and NO completion calls in this proc: the driver calls it
-- inside ONE publish transaction (all branches together, so a publish
-- either lands completely or not at all). Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TRS_MNGSW_C_S_TRS_PTY_MNG_ATTR (

    P_RUN_TS       TIMESTAMP_NTZ DEFAULT NULL

)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO C_S_TRS_PTY_MNG_ATTR
           (PKEY_SRC_OBJECT, ROWID_OBJECT, DELETED_IND, DELETED_DATE, DELETED_BY, PERIOD_START_DATE, PERIOD_END_DATE,
            MNG_ATTR_TP, MNG_ATTR_VAL, VERSION_SEQ, PERIOD_REFERENCE_TIME, TIMELINE_ACTION, UPDATED_BY, CREATE_DATE,
            SRC_ROWID, CREATOR, LAST_UPDATE_DATE, SRC_LAST_UPD_DT, PTY_FK, HUB_STATE_IND)
    SELECT t.pkey_src_object, NULL, NULL, NULL, NULL, t.EFF_BEGIN_DT, NULL,
           t.ATTR_TYPE, t.ATTR_VALUE, 1, NULL, NULL, NULL, :P_RUN_TS, t.pkey_src_object, NULL, :P_RUN_TS, t.SRC_LAST_UPD_DT,
           t.PTY_PK, NULL
      FROM WRK_TRS_MNGSW_S40_ATTRS t
      LEFT JOIN (SELECT DISTINCT PKEY_SRC_OBJECT FROM C_S_TRS_PTY_MNG_ATTR WHERE VERSION_SEQ = 1) xa
             ON xa.PKEY_SRC_OBJECT = t.pkey_src_object
     WHERE xa.PKEY_SRC_OBJECT IS NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY t.pkey_src_object ORDER BY t.EFF_BEGIN_DT DESC NULLS LAST) = 1;
    RETURN SQLROWCOUNT;
END;
$$;
