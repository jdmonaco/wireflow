#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for 'wfw models' command
# Tests model display and show subcommand

# Load existing bats helpers
load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

# Load our custom helpers
source "${BATS_TEST_DIRNAME}/../test_helper/mock_env.sh"

# Setup test environment
setup() {
    setup_test_env
    mock_global_config "${BATS_TEST_TMPDIR}" >/dev/null
    export SCRIPT_DIR="${BATS_TEST_DIRNAME}/../../"
    export TEST_WORK_DIR="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$TEST_WORK_DIR"
    cd "$TEST_WORK_DIR"
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# ============================================================================
# Help tests
# ============================================================================

@test "models: shows help with -h" {
    run "${SCRIPT_DIR}/wireflow.sh" models -h
    assert_success
    assert_output --partial "models"
}

@test "models: shows help with --help" {
    run "${SCRIPT_DIR}/wireflow.sh" models --help
    assert_success
    assert_output --partial "models"
}

@test "models: shows detailed help with 'help models'" {
    run "${SCRIPT_DIR}/wireflow.sh" help models
    assert_success
    assert_output --partial "Display model and profile configuration"
}

# ============================================================================
# Models list tests
# ============================================================================

@test "models: shows Anthropic section header" {
    run "${SCRIPT_DIR}/wireflow.sh" models
    assert_success
    assert_output --partial "Anthropic"
}

@test "models: shows profile configuration" {
    run "${SCRIPT_DIR}/wireflow.sh" models
    assert_success
    assert_output --partial "Profile:"
    assert_output --partial "fast:"
    assert_output --partial "balanced:"
    assert_output --partial "deep:"
}

@test "models: shows Available Models section" {
    run "${SCRIPT_DIR}/wireflow.sh" models
    assert_success
    assert_output --partial "Available Models:"
}

# ============================================================================
# Models show tests
# ============================================================================

@test "models show: requires model ID" {
    run "${SCRIPT_DIR}/wireflow.sh" models show
    assert_failure
    assert_output --partial "Model ID required"
}

@test "models show: handles unknown model gracefully" {
    run "${SCRIPT_DIR}/wireflow.sh" models show nonexistent-model-xyz-12345
    assert_failure
    assert_output --partial "not found"
}

# ============================================================================
# Unknown subcommand tests
# ============================================================================

@test "models: rejects unknown subcommand" {
    run "${SCRIPT_DIR}/wireflow.sh" models foobar
    assert_failure
    assert_output --partial "Unknown models subcommand"
}
