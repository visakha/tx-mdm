-- ============================================================================
-- sp_snow_pub_CRE_CARE_CRE_SRC_MRG  --  BARE-BONES PUBLISH BRANCH (CRE)
--
-- Mapping: m_Tgt_C_S_CRE_CARE_Clients, workflow wf_CRE_Stage_Load_Ongoing.
-- Target: CRE_SRC_MRG. Consumes WRK_CRE_CARE_S5_KEYED only.
--
-- Bare-bones variant: no parameters. P_RUN_TS is NOT kept: the
-- INSERT reads the run_ts / mapping_name columns materialised
-- in step 50, and references neither an original parameter nor
-- the run timestamp directly. The INSERT below is the v2.1
-- branch INSERT verbatim. No transaction control, no checkpoint.
-- The driver calls it inside ONE publish transaction.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_CRE_CARE_CRE_SRC_MRG ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO CRE_SRC_MRG (SRC_ROWID_OBJECT, TGT_ROWID_OBJECT, RUN_DATE)
    SELECT src_rowid_object, tgt_rowid_object, run_ts
      FROM WRK_CRE_CARE_S5_KEYED
     WHERE grp_mrg;
    RETURN SQLROWCOUNT;
END;
$$;
