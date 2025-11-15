#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Initialize a project for all tests (suppress output)
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1
}

teardown() {
    cleanup_test_env
}

@test "list: shows message when no workflows exist" {
    run bash "$WORKFLOW_SCRIPT" list

    assert_success
    assert_output --partial "no workflows found"
    assert_output --partial "workflow new"
}

@test "list: lists existing workflows" {
    # Create some workflows (suppress output)
    bash "$WORKFLOW_SCRIPT" new workflow-01 > /dev/null 2>&1
    bash "$WORKFLOW_SCRIPT" new workflow-02 > /dev/null 2>&1
    bash "$WORKFLOW_SCRIPT" new workflow-03 > /dev/null 2>&1

    run bash "$WORKFLOW_SCRIPT" list

    assert_success
    assert_output --partial "workflow-01"
    assert_output --partial "workflow-02"
    assert_output --partial "workflow-03"
}

@test "list: does not list special directories" {
    bash "$WORKFLOW_SCRIPT" new my-workflow > /dev/null 2>&1

    run bash "$WORKFLOW_SCRIPT" list

    assert_success
    assert_output --partial "my-workflow"
    refute_output --partial "config"
    refute_output --partial "prompts"
    refute_output --partial "output"
    refute_output --partial "project.txt"
}

@test "list: shows incomplete status for workflow missing task.txt" {
    bash "$WORKFLOW_SCRIPT" new incomplete-workflow > /dev/null 2>&1

    # Remove task.txt
    rm .workflow/incomplete-workflow/task.txt

    run bash "$WORKFLOW_SCRIPT" list

    assert_success
    assert_output --partial "incomplete-workflow"
    assert_output --partial "incomplete - missing task.txt"
}

@test "list: shows incomplete status for workflow missing config" {
    bash "$WORKFLOW_SCRIPT" new incomplete-workflow > /dev/null 2>&1

    # Remove config
    rm .workflow/incomplete-workflow/config

    run bash "$WORKFLOW_SCRIPT" list

    assert_success
    assert_output --partial "incomplete-workflow"
    assert_output --partial "incomplete - missing config"
}

@test "list: 'ls' alias works" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    run bash "$WORKFLOW_SCRIPT" ls

    assert_success
    assert_output --partial "test-workflow"
}

@test "list: fails when not in workflow project" {
    cd "$TEST_TEMP_DIR"

    run bash "$WORKFLOW_SCRIPT" list

    assert_failure
    assert_output --partial "Not in workflow project"
}

@test "list: works from subdirectory within project" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    mkdir subdir
    cd subdir

    run bash "$WORKFLOW_SCRIPT" list

    assert_success
    assert_output --partial "test-workflow"
}
