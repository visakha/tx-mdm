# PUBLISH_DEACTIVATE / PUBLISH_REACTIVATE - S10-only twins

Built the same way as the publish_dest S10 twins: ONLY the first (source)
step is inlined as a CTE, every target column is aliased straight to the
target, and the WHERE gate is dropped. 17 twins, 127 target columns,
15 NULLs (ECI deact 1, FSS deact 1, TRS deact 13, everything else 0).

## Sets

publish_deactivate (10) - ECI 2 (VAL deactivation log, VAL new-status),
FSS 2 (VAL inactive log, VAL new-status), TRS 2 (PTYDEACT deactivated
members, RELDEACT deactivated relationships), TTF 2, WIC 2. CRE has no
deactivation/reactivation publish files.
publish_reactivate (7) - ECI 4 (VAL reactivation log + the RFA/RFM/RFP
family-address / Medicaid / family-phone reactivation trio), FSS 1
(VAL reactivation status), TTF 1, WIC 1.

Excluded: TRS VALID_MEMBERS - it is the ongoing party mapping's publish,
not a deactivation publish (the deactivation driver reads it downstream).

## What the S10 rule costs here

- WHERE gates dropped: `grp_deactivation` (VAL log twins),
  `grp_deactivation AND deactivation_sts IS NULL` (VAL new-status twins;
  WIC's variant is `name_missing AND deactivation_sts IS NULL`),
  `grp_reactivation` (VAL reactivation twins; WIC's variant is
  `deactivation_sts IS NOT NULL AND NOT name_missing`). The TRS
  deactivation publishes have no gate. A twin therefore lands EVERY
  first-step row, labelled with the action - the row filter is gone.
- Action labels KEPT: the routing step produces `action_deactivation`
  / `action_reactivation` as literals ('Deactivation' / 'Reactivation'),
  and a literal producer anywhere in the chain is kept. Correction to
  the single example twin shown before the build: it had ACTION = NULL;
  the generated twins carry the literal, so the shipped twins are
  better than that example. The deactivation and reactivation twins for
  the same target are NOT identical - the action label differs.
- TRS PTYDEACT: INDV_ID / PTY_PK / SRC_TBL / CREATE_DATE are NULL -
  they come from STG_TRS_VALID_MEMBERS at step 30, a real table, not
  the chain. INACTIVE_IND / DELETE_SW / SRC_DEACTIVATION_DATE carry the
  row's own first-step values (the per-key MAX/MIN of step 20 is
  dropped; a bare aggregate would collapse the twin to one row and the
  twin form has no GROUP BY).
- TRS RELDEACT: 9 NULLs - the relationship payload (INDV_ID,
  REF_INDV_ID, REL_TYPE_CODE, PKEY_SRC_OBJECT, ROWID_OBJECT,
  MASTER_RECORD_YN, MERGED_YN, SRC_PKEY_CT) enters at step 20 from real
  staging tables, the same class of gap as TRS ADDR2 in publish_dest.
  ROWID_XREF is NULL (trace too deep through the xref CTEs).
- ECI/FSS new-status twins: DEACTIVATION_STS is NULL - it comes from
  helper02 over a real-table hub lookup, not from the first step.

## Generator work

Two bugs found and fixed at generator level (patches 6 and 7, same
convention as patches 1-5): a trailing bare alias after a function call
(`MAX(inactive_ind) inactive_ind`) was not recognised as an alias, so
the column looked unproduced; strip_alias did not strip bare aliases,
so an alias leaked into reduced expressions; and a bare aggregate kept
in a final SELECT would collapse it to one row, so MAX/MIN now reduce
to their argument and other aggregates to NULL. Re-running the
publish_dest S10 generator with patches 6+7 produces byte-identical
S10 twins and maps - the shipped publish_dest content is unaffected.

## Verification

- Structural (check_deact_react_twins.py): 17/17 PASS - same filename,
  STG_* target, exactly ONE CTE matching the v1 twin's first CTE
  verbatim, INSERT target + column list identical to the original,
  final SELECT item count == target column count, each aliased
  AS its target column, every referenced column an output of the kept
  CTE, no unbound :variables, no WRK_ from CREATE onward, no `;;`.
- Live compile (compile_deact_react_key.py): 17/17 OK, 0 errors, in
  scratch database DEACT_REACT_COMPILE_DB (CREATE only, no CALLs).
  Same honest limit as the other compiles: CREATE PROCEDURE does not
  resolve object references or call arity inside bodies.
