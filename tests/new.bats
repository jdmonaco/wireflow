#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Initialize a project for all tests
    bash "$WORKFLOW_SCRIPT" init .
}

teardown() {
    cleanup_test_env
}

@test "new: creates workflow directory with required files" {
    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_success
    assert_dir_exists ".workflow/test-workflow"
    assert_file_exists ".workflow/test-workflow/task.txt"
    assert_file_exists ".workflow/test-workflow/config"
}

@test "new: creates valid template config" {
    bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_file_exists ".workflow/test-workflow/config"

    # Check config has expected template content
    run cat .workflow/test-workflow/config
    assert_output --partial "# Workflow-specific configuration"
    assert_output --partial "CONTEXT_PATTERN"
    assert_output --partial "CONTEXT_FILES"
    assert_output --partial "DEPENDS_ON"
    assert_output --partial "Paths in CONTEXT_PATTERN and CONTEXT_FILES are relative to project root"
}

@test "new: creates empty task.txt" {
    bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_file_exists ".workflow/test-workflow/task.txt"

    # Should be empty (just created)
    [[ ! -s ".workflow/test-workflow/task.txt" ]]
}

@test "new: fails when workflow name not provided" {
    run bash "$WORKFLOW_SCRIPT" new

    assert_failure
    assert_output --partial "Workflow name required"
}

@test "new: fails when workflow already exists" {
    # Create workflow first time
    bash "$WORKFLOW_SCRIPT" new test-workflow

    # Try to create again
    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_failure
    assert_output --partial "already exists"
}

@test "new: fails when not in workflow project" {
    # Move outside project
    cd "$TEST_TEMP_DIR"

    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_failure
    assert_output --partial "Not in workflow project"
}

@test "new: works from subdirectory within project" {
    # Create a subdirectory and work from there
    mkdir subdir
    cd subdir

    run bash "$WORKFLOW_SCRIPT" new test-workflow

    assert_success
    assert_dir_exists "../.workflow/test-workflow"
}

@test "new: workflow name with numbers and dashes" {
    run bash "$WORKFLOW_SCRIPT" new 01-my-workflow

    assert_success
    assert_dir_exists ".workflow/01-my-workflow"
}
