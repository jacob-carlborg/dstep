Feature: Variable
  
  Scenario: Convert variables
    Given a test file named "variables"
    And a expected file named "variables"
    When I successfully run `dstep variables.c -o variables.d`
    Then the files "variables.d" and "test_files/variables.d" should be equal