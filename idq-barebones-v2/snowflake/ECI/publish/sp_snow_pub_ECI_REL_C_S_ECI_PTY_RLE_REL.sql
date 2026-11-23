-- sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL -- BARE-BONES variant (ECI)
-- Mapping: m_Tgt_C_S_ECI_Pty_Rle_Rel, workflow wf_ECI_Stage_Load, publish step 50 (PUBLISH_C_S_ECI_PTY_RLE_REL).
-- Target: C_S_ECI_PTY_RLE_REL. Consumes: WRK_ECI_REL_S40_READY.
-- Called by the driver inside the single publish transaction; no gating, no checkpointing.
-- INSERT below is verbatim from the v2.1 publish procedure.
CREATE OR REPLACE PROCEDURE sp_snow_pub_ECI_REL_C_S_ECI_PTY_RLE_REL ()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 50a. Valid relationships -> C_S_ECI_PTY_RLE_REL (verbatim from the main)
    INSERT INTO C_S_ECI_PTY_RLE_REL
           (PTY_RLE_FK_1, PTY_RLE_FK_2, PKEY_SRC_OBJECT, VERSION_SEQ, SRC_ROWID, HUB_STATE_IND, REL_TYPE_CODE,
            HIERARCHY_CODE, REL_TP, SRC_LAST_UPD_DT, LAST_UPDATE_DATE, UPDATED_BY, CREATE_DATE, CREATOR,
            PERIOD_START_DATE)
    SELECT rel_fk_1, rel_fk_2, rel_src_key, version_seq, rel_src_key, hub_state_ind, rel_type_code,
           hierarchy_code, mstr_ref_code, DATE_MODIFIED, run_ts, mapping_name, DATE_MODIFIED, mapping_name,
           DATE_CREATED
      FROM WRK_ECI_REL_S40_READY
     WHERE mstr_ref_code IS NOT NULL AND uq_rel;
    RETURN SQLROWCOUNT;
END;
$$;
