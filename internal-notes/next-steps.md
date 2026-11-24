# Next steps / open items (refreshed 2026-11-23, 0.9.17)

The original list here (first live read, MDM job-id source, first live run, advanced taskflows)
is DONE: the app has run live against his org since 2026-11-22 evening (CDI tasks, taskflows,
B360 ingress / egress, Monitor, B360 Data, Design). How we work now: `collaboration-spine.md`.

Open, in no fixed order (he picks):

1. **Mapping-task run portal link.** Plain MTT runs have no "Go to IDMC" link: no URL pattern
   yet (`MTT_RUN_PATH = None` in `app/common/portal.py`). Needs one sample URL from Vamsi's
   browser for a mapping-task run page. Never guess it.
2. **Merge 141 + 150 not recorded as run.** His ask: merge business ids 100000000000141 and
   100000000000150, first name from 141, last name from 150 (expected survivor "Charles
   Harrison"). The Merge (M) tab exists (0.9.12); no record that the merge was pressed / landed.
3. **Portal links not clicked in a real browser.** B360 job links, taskflow "Go to IDMC" and the
   Design asset links (0.9.15 / 0.9.16) are tested against the fake IDMC + vitest only.
4. **ffr_first_name / ffr_last_name NULL in master** on created records although the preview
   fills them. Cause unknown.
5. **Backend bound to the Tailscale address.** Run with `--host 100.111.71.101` so Muse can
   reach it; then the localhost UI cannot. Option: bind 0.0.0.0 (firewall rule already limits
   port 8000 to 100.64.0.0/10) or run two listeners. His call.
6. **0.9.17 Design keyboard rows + own-name filter** not yet seen on his screen (fake IDMC +
   vitest only). Live counts known: Mapping 48 -> 14 shown / 34 hidden; MTT 11 and Taskflow 4,
   none hidden.
7. **Own-name rule for connections / runtime environments**: no convention from him yet. Names
   seen live 2026-11-23: connections HIP_ORCL_LND, HIP_ORCL_STG, MDM_CDI_SNOW_SRC, ORA_MDM_ORS,
   ora_mdm_stg, zlv_b360_fep; runtime environments abc, abd, Abhilash-laptop-SA, hhsc4avmdm1d,
   IDMC_CDGC_Linux_SAGroup, Vamsi-laptop-grp, vamsi-laptop-SA-01, vamsi-laptop-sa01.

Optional, only if asked: persist runs (RunRegistry is in memory); link CDI tasks to the
barebones-v2 tables (`barebones-v2-and-cdi.md`, "Not linked yet").

8. **Linux-box Secure Agent** (2026-11-23 22:44, Vamsi): runtime environment hhsc4avmdm1d is the agent on his Linux box. Mapping tasks still on Vamsi-laptop-grp; switch to hhsc4avmdm1d for unattended real runs - not changed, his call.

9. **Testing harness 0.10.0** (built 2026-11-23): mock path green for TTF use-case-1..11 and
   MDM use-case-1..4. Real path needs: real source loader (Oracle/Snowflake), a match-merge job in
   his org, the real "invalid phone" reason field, DEMOGRAPHICS phone -> x_phone mapping, MDM-group
   job APIs, real egress tables. All test_config.toml values are Muse picks; MDM use cases are
   drafts he has not reviewed. Runtime-environment PUT exists (item 8) but was not run on his org.
