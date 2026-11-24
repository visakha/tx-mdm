Feature: MDM use cases on the tx-mdm test path
  MDM only: seed records -> MDM job (match-merge / reset / index / purge) -> read -> compare.

  Background:
    Given the tx-mdm backend is reachable

  Scenario Outline: <use_case> <title> runs end to end and matches Expected
    Given a test-case folder for MDM <use_case>, generated template if it has none
    When the runner runs MDM <use_case>
    Then the run state is PASSED
    And every comparison check passed
    And the result workbook and the run log are in the test-case folder

    Examples:
      | use_case    | title                 |
      | use-case-1  | Match and merge only  |
      | use-case-2  | Reset matched records |
      | use-case-3  | Search indexing       |
      | use-case-4  | Purge                 |
