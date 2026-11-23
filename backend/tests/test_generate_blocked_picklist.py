"""0.9.11.1: a required picklist with no known codes must never cause a bare 500."""

from datetime import datetime

import pytest

from app.b360data import testdata
from app.b360data.models import BusinessEntity


def _entity(root_picklist_required: bool) -> BusinessEntity:
    return BusinessEntity.model_validate(
        {
            "name": "zlv_guest",
            "label": "ZLV Guest",
            "fields": [
                {
                    "name": "first_name",
                    "label": "First",
                    "data_type": "STRING",
                    "raw_type": "TextField",
                    "searchable": False,
                    "mandatory": True,
                },
                {
                    "name": "kind",
                    "label": "Kind",
                    "data_type": "PICKLIST",
                    "raw_type": "PicklistField",
                    "searchable": False,
                    "mandatory": root_picklist_required,
                },
            ],
            "field_groups": [
                {
                    "name": "x_phone",
                    "label": "x_phone",
                    "cardinality": "MANY",
                    "fields": [
                        {
                            "name": "ph_num",
                            "label": "ph",
                            "data_type": "INTEGER",
                            "raw_type": "IntegerField",
                            "searchable": False,
                            "mandatory": True,
                        },
                        {
                            "name": "ph_typ",
                            "label": "typ",
                            "data_type": "PICKLIST",
                            "raw_type": "PicklistField",
                            "searchable": False,
                            "mandatory": True,
                        },
                    ],
                },
            ],
        }
    )


def test_group_with_unknown_required_picklist_is_skipped() -> None:
    rows = testdata.generate(_entity(False), 3, 1, datetime(2026, 11, 23))
    assert len(rows.rows) == 3
    for row in rows.rows:
        assert [g.rows for g in row.groups if g.group == "x_phone"] == [[]]
    assert any("group skipped" in r.rule for r in rows.rules if r.field.startswith("x_phone."))


def test_root_required_picklist_unknown_raises_clear_error() -> None:
    with pytest.raises(testdata.GenerateBlockedError, match="kind"):
        testdata.generate(_entity(True), 1, 1, datetime(2026, 11, 23))
