#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env
}

teardown() {
    unmock_curl
    cleanup_test_env
}

@test "task: --enable-citations option is documented" {
    # Check full help documentation
    run bash "$WORKFLOW_SCRIPT" help task

    assert_success
    assert_output --partial "--enable-citations"
}

@test "task: --disable-citations option is documented" {
    # Check full help documentation
    run bash "$WORKFLOW_SCRIPT" help task

    assert_success
    assert_output --partial "--disable-citations"
}

# Note: Full citations functionality tests would require mocking API responses with citations
# These tests verify the options exist and are documented
