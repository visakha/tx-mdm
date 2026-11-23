"""Which taskflows belong to Business 360 / MDM and which to plain CDI. ONE place for the rule.

Vamsi's naming rule (voice, 2026-11-23 00:41 CST):
- MDM / B360 taskflow: name starts with "tf_MDM_", or ends with "_EGR" (egress) or "_IGR"
  (ingress). These need the Start-step input field jobInstanceId and live in the Business 360
  notebook of the UI, next to the B360 ingress / egress jobs.
- CDI taskflow: everything else, in particular names starting "tf_Ldg_" or "tf_Stg_" - even when
  they contain "MDM" (tf_Stg_MDM_CDI_TTF is CDI). They must NOT get jobInstanceId: live
  2026-11-23 06:39Z, tf_Stg_MDM_CDI_TTF answered IDMC 400 "Validation failed, extra:
  jobInstanceId" when it was sent.
Matching ignores case. Only advanced taskflows (TASKFLOW) are classified; mapping tasks and
linear taskflows are always "cdi".
"""

from enum import StrEnum

JOB_INSTANCE_ID = "jobInstanceId"

_CDI_PREFIXES = ("tf_ldg_", "tf_stg_")
_MDM_PREFIXES = ("tf_mdm_",)
_MDM_SUFFIXES = ("_egr", "_igr")


class TaskDomain(StrEnum):
    CDI = "cdi"
    MDM = "mdm"


def is_mdm_taskflow(name: str) -> bool:
    lowered = name.strip().lower()
    if lowered.startswith(_CDI_PREFIXES):
        return False
    return lowered.startswith(_MDM_PREFIXES) or lowered.endswith(_MDM_SUFFIXES)


def taskflow_domain(name: str) -> TaskDomain:
    return TaskDomain.MDM if is_mdm_taskflow(name) else TaskDomain.CDI


def parameter_problem(name: str, parameters: dict[str, str] | None) -> str | None:
    """Why these input fields are wrong for this taskflow, or None when they are fine."""
    params = parameters or {}
    if is_mdm_taskflow(name):
        value = params.get(JOB_INSTANCE_ID, "")
        if value.strip() == "":
            return (
                f"{name} is a Business 360 / MDM taskflow (tf_MDM_*, *_EGR or *_IGR): it needs "
                f"the input field {JOB_INSTANCE_ID} (exact name) with a value, e.g. "
                f'{{"parameters": {{"{JOB_INSTANCE_ID}": "<id>"}}}}. Not sent to IDMC.'
            )
        return None
    if any(key.strip().lower() == JOB_INSTANCE_ID.lower() for key in params):
        return (
            f"{name} is a CDI taskflow: it takes no {JOB_INSTANCE_ID} (IDMC would answer 400 "
            f'"Validation failed, extra: {JOB_INSTANCE_ID}"). Remove it. Not sent to IDMC.'
        )
    return None
