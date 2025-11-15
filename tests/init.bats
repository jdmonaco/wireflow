#!/usr/bin/env bats

load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "init: creates .workflow directory with all required files" {
    run bash "$WORKFLOW_SCRIPT" init .

    assert_success
    assert_dir_exists ".workflow"
    assert_dir_exists ".workflow/prompts"
    assert_dir_exists ".workflow/output"
    assert_file_exists ".workflow/config"
    assert_file_exists ".workflow/project.txt"
}

@test "init: creates config with empty values for global default pass-through" {
    bash "$WORKFLOW_SCRIPT" init .

    assert_file_exists ".workflow/config"

    # Source config and check values are empty (for pass-through)
    source .workflow/config
    assert_equal "$MODEL" ""
    assert_equal "$TEMPERATURE" ""
    assert_equal "$MAX_TOKENS" ""
    assert_equal "$OUTPUT_FORMAT" ""
    assert_equal "${#SYSTEM_PROMPTS[@]}" "0"  # Empty array

    # Config should contain comments showing inherited defaults
    run cat .workflow/config
    assert_output --partial "Current inherited defaults:"
    assert_output --partial "MODEL="
    assert_output --partial "TEMPERATURE="
}

@test "init: fails when project already initialized" {
    # First init succeeds
    bash "$WORKFLOW_SCRIPT" init .

    # Second init fails
    run bash "$WORKFLOW_SCRIPT" init .

    assert_failure
    assert_output --partial "already initialized"
}

@test "init: can initialize in specified directory" {
    mkdir subdir

    run bash "$WORKFLOW_SCRIPT" init subdir

    assert_success
    assert_dir_exists "subdir/.workflow"
}

@test "init: nested project detects parent and inherits config" {
    # Create parent project
    bash "$WORKFLOW_SCRIPT" init .

    # Modify parent config
    cat >> .workflow/config <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.5
SYSTEM_PROMPTS=(base NeuroAI)
EOF

    # Create nested project (respond 'y' to prompt)
    mkdir nested
    cd nested

    run bash -c "echo 'y' | bash '$WORKFLOW_SCRIPT' init ."

    assert_success
    assert_output --partial "Initializing nested project"
    assert_output --partial "Inheriting configuration"
    assert_output --partial "claude-opus-4"
    assert_output --partial "0.5"

    # Verify config uses empty values for transparent pass-through
    source .workflow/config
    assert_equal "$MODEL" ""
    assert_equal "$TEMPERATURE" ""
    # But the display should have shown inherited values during init
    # (checked earlier in assert_output)
}

@test "init: nested project can decline inheritance" {
    # Create parent
    bash "$WORKFLOW_SCRIPT" init .

    # Create nested, respond 'n' to prompt
    mkdir nested
    cd nested

    run bash -c "echo 'n' | bash '$WORKFLOW_SCRIPT' init ."

    # Should exit without creating project
    assert_success
    [[ ! -d ".workflow" ]]
}
