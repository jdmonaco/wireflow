#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Initialize a project for all tests
    bash "$WORKFLOW_SCRIPT" init .

    # Create a test workflow
    bash "$WORKFLOW_SCRIPT" new test-workflow
}

teardown() {
    cleanup_test_env
}

@test "edit: opens workflow files when name provided" {
    run bash "$WORKFLOW_SCRIPT" edit test-workflow

    assert_success
    # With mocked EDITOR=echo, output shows what would be opened
    assert_output --partial ".workflow/test-workflow/task.txt"
    assert_output --partial ".workflow/test-workflow/config"
}

@test "edit: opens project files when no name provided" {
    run bash "$WORKFLOW_SCRIPT" edit

    assert_failure
    assert_output --partial "Workflow name required"
}

@test "edit: fails when workflow doesn't exist" {
    run bash "$WORKFLOW_SCRIPT" edit nonexistent-workflow

    assert_failure
    assert_output --partial "not found"
}

@test "edit: lists available workflows when workflow not found" {
    # Create multiple workflows
    bash "$WORKFLOW_SCRIPT" new workflow-01
    bash "$WORKFLOW_SCRIPT" new workflow-02

    run bash "$WORKFLOW_SCRIPT" edit nonexistent

    assert_failure
    assert_output --partial "Available workflows:"
    assert_output --partial "test-workflow"
    assert_output --partial "workflow-01"
    assert_output --partial "workflow-02"
}

@test "edit: fails when not in workflow project" {
    # Move outside project
    cd "$TEST_TEMP_DIR"

    run bash "$WORKFLOW_SCRIPT" edit test-workflow

    assert_failure
    assert_output --partial "Not in workflow project"
}

@test "edit: works from subdirectory within project" {
    mkdir subdir
    cd subdir

    run bash "$WORKFLOW_SCRIPT" edit test-workflow

    assert_success
    assert_output --partial ".workflow/test-workflow"
}
