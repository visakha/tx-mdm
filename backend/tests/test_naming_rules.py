"""0.9.13: declarative name rules keep the old behaviour (no regex)."""

from app.b360data.testdata import _derived, _is_freeform_reason
from app.cdi.taskflow_kind import TaskDomain, mapping_task_domain, taskflow_domain
from app.common.naming import Transform, apply, is_identifier
from app.mdm.resolver import normalise


def test_taskflow_rule_table() -> None:
    assert taskflow_domain("tf_MDM_ZLV_TTF_Guest_Basic") == TaskDomain.MDM
    assert taskflow_domain("Guest_EGR") == TaskDomain.MDM
    assert taskflow_domain("guest_igr") == TaskDomain.MDM
    assert taskflow_domain("tf_Stg_MDM_CDI_TTF") == TaskDomain.CDI  # CDI rows win
    assert taskflow_domain("tf_Ldg_x_EGR") == TaskDomain.CDI
    assert taskflow_domain("anything") == TaskDomain.CDI
    assert mapping_task_domain("mt_m_MDM_x") == TaskDomain.MDM
    assert mapping_task_domain("mt_m_Stg_MDM_x") == TaskDomain.CDI


def test_transforms() -> None:
    assert apply(Transform.UPPER_ALNUM, "O'Brien-Smith 2") == "OBRIENSMITH2"
    assert normalise("  ZLV Guest -- Ingress! ") == "zlv_guest_ingress"
    assert apply(Transform.SCHEMA_KEY, "rdm.value.be._ent") == "rdm_value_be__ent"
    assert is_identifier("zlv_ttf", 128) and is_identifier("c360.default.system", 128)
    assert not is_identifier("a b", 128) and not is_identifier("", 128)


def test_field_roles() -> None:
    assert _derived("clns_first_name") == (
        "first_name",
        "cleansed: upper-case, letters and digits only",
    )
    assert _derived("clns_") is None and _derived("first_name") is None
    assert _is_freeform_reason("ffr_first_name") and not _is_freeform_reason("ffr_")
