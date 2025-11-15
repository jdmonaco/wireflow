#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env

    # Initialize a project for all tests
    bash "$WORKFLOW_SCRIPT" init . > /dev/null 2>&1
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# config_project (no workflow name) Tests
# =============================================================================

@test "config: displays project configuration with global defaults" {
    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config"

    assert_success
    assert_output --partial "Project Configuration"
    assert_output --partial "Location:"
    assert_output --partial "Configuration:"
    # With empty project config, all values pass through from global defaults
    assert_output --partial "MODEL: claude-sonnet-4-5 (default)"
    assert_output --partial "TEMPERATURE: 1.0 (default)"
    assert_output --partial "MAX_TOKENS: 4096 (default)"
    assert_output --partial "SYSTEM_PROMPTS: Root (default)"
    assert_output --partial "OUTPUT_FORMAT: md (default)"
}

@test "config: displays custom project configuration" {
    # Modify project config
    cat >> .workflow/config <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.5
SYSTEM_PROMPTS=(Root NeuroAI)
EOF

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config"

    assert_success
    assert_output --partial "MODEL: claude-opus-4"
    assert_output --partial "TEMPERATURE: 0.5"
    assert_output --partial "SYSTEM_PROMPTS: Root NeuroAI"
}

@test "config: lists workflows in project config" {
    # Create some workflows
    bash "$WORKFLOW_SCRIPT" new workflow-01 > /dev/null 2>&1
    bash "$WORKFLOW_SCRIPT" new workflow-02 > /dev/null 2>&1

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config"

    assert_success
    assert_output --partial "Workflows:"
    assert_output --partial "workflow-01"
    assert_output --partial "workflow-02"
}

@test "config: shows no workflows when none exist" {
    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config"

    assert_success
    assert_output --partial "Workflows:"
    assert_output --partial "(no workflows found)"
}

@test "config: completes successfully when declining edit" {
    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config"

    assert_success
    # Verify it showed config and completed (prompt text may not appear in output)
    assert_output --partial "Project Configuration"
}

@test "config: fails when not in workflow project" {
    cd "$TEST_TEMP_DIR"

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config"

    assert_failure
    assert_output --partial "Not in workflow project"
}

# =============================================================================
# config_workflow (with workflow name) Tests
# =============================================================================

@test "config NAME: displays workflow configuration with defaults" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config test-workflow"

    assert_success
    assert_output --partial "Workflow Configuration: test-workflow"
    assert_output --partial "Location:"
    assert_output --partial "API Settings:"
    assert_output --partial "MODEL: claude-sonnet-4-5 (default)"
    assert_output --partial "TEMPERATURE: 1.0 (default)"
    assert_output --partial "MAX_TOKENS: 4096 (default)"
}

@test "config NAME: shows config cascade from project" {
    # Modify project config
    cat >> .workflow/config <<'EOF'
MODEL="claude-opus-4"
SYSTEM_PROMPTS=(Root NeuroAI)
EOF

    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config test-workflow"

    assert_success
    assert_output --partial "MODEL: claude-opus-4 (project)"
    assert_output --partial "SYSTEM_PROMPTS: Root NeuroAI (project)"
    assert_output --partial "TEMPERATURE: 1.0 (default)"
}

@test "config NAME: shows workflow overrides" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    # Add workflow-specific config
    cat >> .workflow/test-workflow/config <<'EOF'
MODEL="claude-sonnet-4"
MAX_TOKENS=8192
EOF

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config test-workflow"

    assert_success
    assert_output --partial "MODEL: claude-sonnet-4 (workflow)"
    assert_output --partial "MAX_TOKENS: 8192 (workflow)"
    assert_output --partial "TEMPERATURE: 1.0 (default)"
}

@test "config NAME: displays context sources" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    # Configure context sources
    cat >> .workflow/test-workflow/config <<'EOF'
CONTEXT_PATTERN="References/*.md"
CONTEXT_FILES=("data/file1.md" "data/file2.md")
DEPENDS_ON=("workflow-01")
EOF

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config test-workflow"

    assert_success
    assert_output --partial "Context Sources:"
    assert_output --partial "CONTEXT_PATTERN: References/*.md"
    assert_output --partial "CONTEXT_FILES: data/file1.md data/file2.md"
    assert_output --partial "DEPENDS_ON: workflow-01"
}

@test "config NAME: no context section when no sources configured" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config test-workflow"

    assert_success
    refute_output --partial "Context Sources:"
}

@test "config NAME: completes successfully when declining edit" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config test-workflow"

    assert_success
    # Verify it showed config and completed
    assert_output --partial "Workflow Configuration: test-workflow"
}

@test "config NAME: fails when workflow doesn't exist" {
    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config nonexistent"

    assert_failure
    assert_output --partial "not found"
    assert_output --partial "Available workflows:"
}

@test "config NAME: works from subdirectory" {
    bash "$WORKFLOW_SCRIPT" new test-workflow > /dev/null 2>&1

    mkdir subdir
    cd subdir

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' config test-workflow"

    assert_success
    assert_output --partial "Workflow Configuration: test-workflow"
}
