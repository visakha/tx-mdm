-- ============================================================================
-- sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_STS -- BARE-BONES variant (TTF)
--
-- No config table, no checkpointing, no job-run id. The INSERT below
-- is verbatim from v2.1. No transaction control in this proc; the
-- driver calls it inside one publish transaction. Returns SQLROWCOUNT.
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_snow_pub_TTF_VAL_STG_TTF_PTY_INACTIVE_STS (
)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
INSERT INTO STG_TTF_PTY_INACTIVE_STS (SRC_KEY, ROWID_SYSTEM, DEACTIVATION_STS, DEACTIVATION_DT)
    SELECT pkey_src_object, src_sys, new_deactivation_sts, run_ts
      FROM WRK_TTF_VAL_S3_ROUTED
     WHERE grp_deactivation AND deactivation_sts IS NULL;
    RETURN SQLROWCOUNT;
END;
$$;
