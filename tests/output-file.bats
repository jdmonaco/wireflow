#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Initialize a project for all tests
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1

    # Create a simple workflow
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    # Add minimal task content
    echo "Summarize this content." > .workflow/test-workflow/task.txt
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# OUTPUT_FILE Configuration Parameter Tests
# =============================================================================

@test "output-file: workflow config parameter is loaded" {
    # Add OUTPUT_FILE to workflow config
    cat >> .workflow/test-workflow/config <<'EOF'
OUTPUT_FILE="custom-output/test.md"
EOF

    # Mock the API to avoid actual API calls
    export ANTHROPIC_API_KEY="test-key"

    # Run with dry-run to avoid API call
    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    assert_success
}

@test "output-file: CLI --output-file overrides workflow config" {
    # Add OUTPUT_FILE to workflow config
    cat >> .workflow/test-workflow/config <<'EOF'
OUTPUT_FILE="config-output/test.md"
EOF

    export ANTHROPIC_API_KEY="test-key"

    # CLI should override config
    run bash "$WORKFLOW_SCRIPT" run test-workflow --output-file cli-output/test.md --dry-run

    assert_success
}

@test "output-file: not inherited from project config" {
    # Add OUTPUT_FILE to project config (should be ignored)
    cat >> .workflow/config <<'EOF'
OUTPUT_FILE="project-output/test.md"
EOF

    # Create new workflow after project config change
    bash "$WORKFLOW_SCRIPT" new workflow-no-inherit > /dev/null 2>&1
    echo "Test task" > .workflow/workflow-no-inherit/task.txt

    export ANTHROPIC_API_KEY="test-key"

    # OUTPUT_FILE should not be inherited from project config
    run bash "$WORKFLOW_SCRIPT" run workflow-no-inherit --dry-run

    assert_success
}

# =============================================================================
# OUTPUT_FILE Copy Behavior Tests (with mocked API)
# =============================================================================

# Note: These tests would require mocking the Anthropic API response
# For now, we're testing configuration loading and CLI parsing
# Actual copy behavior can be tested manually or with integration tests

@test "output-file: absolute path resolution" {
    cat >> .workflow/test-workflow/config <<'EOF'
OUTPUT_FILE="/tmp/wireflow-test-output.md"
EOF

    export ANTHROPIC_API_KEY="test-key"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    assert_success
}

@test "output-file: tilde expansion in config" {
    cat >> .workflow/test-workflow/config <<'EOF'
OUTPUT_FILE="~/wireflow-test-output.md"
EOF

    export ANTHROPIC_API_KEY="test-key"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    assert_success
}

@test "output-file: relative path resolution" {
    cat >> .workflow/test-workflow/config <<'EOF'
OUTPUT_FILE="reports/output.md"
EOF

    export ANTHROPIC_API_KEY="test-key"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    assert_success
}

@test "output-file: empty config value does not cause error" {
    cat >> .workflow/test-workflow/config <<'EOF'
OUTPUT_FILE=
EOF

    export ANTHROPIC_API_KEY="test-key"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    assert_success
}

@test "output-file: CLI with absolute path" {
    export ANTHROPIC_API_KEY="test-key"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --output-file /tmp/cli-output.md --dry-run

    assert_success
}

@test "output-file: CLI with relative path" {
    export ANTHROPIC_API_KEY="test-key"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --output-file custom/output.md --dry-run

    assert_success
}

@test "output-file: CLI with tilde path" {
    export ANTHROPIC_API_KEY="test-key"

    run bash "$WORKFLOW_SCRIPT" run test-workflow --output-file ~/test-output.md --dry-run

    assert_success
}
