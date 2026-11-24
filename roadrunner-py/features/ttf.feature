Feature: TTF use cases on the tx-mdm test path
  TTF landing -> CDI ldg/stg -> ingress -> match-merge -> egress -> read -> compare.

  Background:
    Given the tx-mdm backend is reachable

  Scenario Outline: <use_case> <title> runs end to end and matches Expected
    Given a test-case folder for TTF <use_case>, generated template if it has none
    When the runner runs TTF <use_case>
    Then the run state is PASSED
    And every comparison check passed
    And the result workbook and the run log are in the test-case folder

    Examples:
      | use_case    | title                      |
      | use-case-1  | New member                 |
      | use-case-2  | Name and phone update      |
      | use-case-3  | Duplicate member           |
      | use-case-4  | Not a duplicate            |
      | use-case-5  | Inactive member            |
      | use-case-6  | Missing required field     |
      | use-case-7  | Orphan demographics row    |
      | use-case-8  | Multi-month member         |
      | use-case-9  | Junk phone numbers         |
      | use-case-10 | Member with no phone       |
      | use-case-11 | Member with several phones |
