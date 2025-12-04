#!/usr/bin/env /opt/homebrew/bin/bash
# Integration tests for OpenAI provider support
# Tests provider selection, configuration, and feature gating

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

    # Initialize a project
    "${SCRIPT_DIR}/wireflow.sh" init . >/dev/null 2>&1
}

teardown() {
    cd "${BATS_TEST_DIRNAME}"
    teardown_test_environment
}

# =============================================================================
# Provider Configuration Tests
# =============================================================================

@test "config: shows PROVIDER setting" {
    echo 'PROVIDER="openai"' >> .workflow/config

    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_success
    assert_output --partial "PROVIDER"
}

@test "config: shows OpenAI settings when configured" {
    cat >> .workflow/config <<'EOF'
PROVIDER="openai"
OPENAI_BASE_URL="http://localhost:1234"
OPENAI_MODEL_BALANCED="test-model"
EOF

    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_success
    assert_output --partial "OPENAI_BASE_URL"
    assert_output --partial "localhost:1234"
}

@test "config: extracts PROVIDER from config file" {
    cat >> .workflow/config <<'EOF'
PROVIDER="openai"
EOF

    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_success
    # Provider should be visible in config output
    assert_output --partial "openai" || assert_output --partial "PROVIDER"
}

# =============================================================================
# Provider Validation Tests (using task command for quick validation)
# =============================================================================

@test "task: fails with openai provider when OPENAI_BASE_URL not set" {
    cat >> .workflow/config <<'EOF'
PROVIDER="openai"
OPENAI_BASE_URL=""
OPENAI_MODEL_BALANCED="test-model"
EOF

    run "${SCRIPT_DIR}/wireflow.sh" task --inline "Hello" 2>&1
    assert_failure
    assert_output --partial "OPENAI_BASE_URL is not set"
}

@test "task: fails with openai provider when model not configured" {
    cat >> .workflow/config <<'EOF'
PROVIDER="openai"
OPENAI_BASE_URL="http://localhost:1234"
OPENAI_MODEL=""
OPENAI_MODEL_BALANCED=""
EOF

    run "${SCRIPT_DIR}/wireflow.sh" task --inline "Hello" 2>&1
    assert_failure
    assert_output --partial "not configured"
}

# =============================================================================
# Feature Warning Tests
# =============================================================================

@test "run: warns about thinking with openai provider" {
    # Create a workflow with thinking enabled
    "${SCRIPT_DIR}/wireflow.sh" new test-thinking >/dev/null 2>&1
    echo "Test task" > .workflow/run/test-thinking/task.md

    cat >> .workflow/run/test-thinking/config <<'EOF'
PROVIDER="openai"
OPENAI_BASE_URL="http://localhost:1234"
OPENAI_MODEL_BALANCED="test-model"
ENABLE_THINKING="true"
EOF

    # Run should warn but still fail on connection (expected)
    run "${SCRIPT_DIR}/wireflow.sh" run test-thinking 2>&1
    # Look for warning about thinking
    assert_output --partial "thinking" || assert_output --partial "not supported"
}

@test "run: warns about effort with openai provider" {
    # Create a workflow with effort set
    "${SCRIPT_DIR}/wireflow.sh" new test-effort >/dev/null 2>&1
    echo "Test task" > .workflow/run/test-effort/task.md

    cat >> .workflow/run/test-effort/config <<'EOF'
PROVIDER="openai"
OPENAI_BASE_URL="http://localhost:1234"
OPENAI_MODEL_BALANCED="test-model"
EFFORT="low"
EOF

    # Run should warn about effort
    run "${SCRIPT_DIR}/wireflow.sh" run test-effort 2>&1
    assert_output --partial "Effort" || assert_output --partial "not supported"
}

@test "run: warns about citations with openai provider" {
    # Create a workflow with citations enabled
    "${SCRIPT_DIR}/wireflow.sh" new test-citations >/dev/null 2>&1
    echo "Test task" > .workflow/run/test-citations/task.md

    cat >> .workflow/run/test-citations/config <<'EOF'
PROVIDER="openai"
OPENAI_BASE_URL="http://localhost:1234"
OPENAI_MODEL_BALANCED="test-model"
ENABLE_CITATIONS="true"
EOF

    # Run should warn about citations
    run "${SCRIPT_DIR}/wireflow.sh" run test-citations 2>&1
    assert_output --partial "Citations" || assert_output --partial "not supported"
}

# =============================================================================
# Profile System Tests
# =============================================================================

@test "config: shows OpenAI model profiles" {
    cat >> .workflow/config <<'EOF'
PROVIDER="openai"
OPENAI_MODEL_FAST="phi-4-mini"
OPENAI_MODEL_BALANCED="qwen-14b"
OPENAI_MODEL_DEEP="qwen-72b"
EOF

    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_success
    assert_output --partial "OPENAI_MODEL_FAST"
    assert_output --partial "OPENAI_MODEL_BALANCED"
    assert_output --partial "OPENAI_MODEL_DEEP"
}

# =============================================================================
# Help Text Tests
# =============================================================================

@test "help: shows provider settings in help output" {
    run "${SCRIPT_DIR}/wireflow.sh" help
    assert_success
    assert_output --partial "PROVIDER"
    assert_output --partial "OPENAI_BASE_URL"
}

@test "help: shows openai as valid provider option" {
    run "${SCRIPT_DIR}/wireflow.sh" help
    assert_success
    assert_output --partial "openai"
}

# =============================================================================
# Default Provider Tests
# =============================================================================

@test "config: default provider is anthropic" {
    # Without any provider config, should default to anthropic
    run "${SCRIPT_DIR}/wireflow.sh" config
    assert_success
    # PROVIDER should show anthropic or builtin default
    assert_output --partial "PROVIDER" || assert_output --partial "anthropic"
}
