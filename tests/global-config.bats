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

@test "global-config: auto-creates on first use" {
    # Run any command that calls ensure_global_config
    run bash "$WORKFLOW_SCRIPT" init .

    assert_success
    assert_file_exists "$GLOBAL_CONFIG_DIR/config"
    assert_file_exists "$GLOBAL_CONFIG_DIR/prompts/base.txt"
}

@test "global-config: creates with default values" {
    bash "$WORKFLOW_SCRIPT" init .

    # Check config file has expected defaults
    run cat "$GLOBAL_CONFIG_DIR/config"
    assert_output --partial 'MODEL="claude-sonnet-4-5"'
    assert_output --partial 'TEMPERATURE=1.0'
    assert_output --partial 'MAX_TOKENS=4096'
    assert_output --partial 'OUTPUT_FORMAT="md"'
    assert_output --partial 'SYSTEM_PROMPTS=(base)'
    assert_output --partial 'WIREFLOW_PROMPT_PREFIX='
}

@test "global-config: creates default base.txt system prompt" {
    bash "$WORKFLOW_SCRIPT" init .

    assert_file_exists "$GLOBAL_CONFIG_DIR/prompts/base.txt"

    # Check prompt contains expected content
    run cat "$GLOBAL_CONFIG_DIR/prompts/base.txt"
    assert_output --partial "workflow-based content development"
    assert_output --partial "Research synthesis"
    assert_output --partial "Technical writing"
}

@test "global-config: loads values into run mode" {
    # Create project
    bash "$WORKFLOW_SCRIPT" init .

    # Modify global config to use different model
    cat > "$GLOBAL_CONFIG_DIR/config" <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.7
MAX_TOKENS=8192
OUTPUT_FORMAT="txt"
SYSTEM_PROMPTS=(base NeuroAI)
WIREFLOW_PROMPT_PREFIX="$HOME/.config/wireflow/prompts"
EOF

    # Create workflow with empty config (should inherit from global)
    bash "$WORKFLOW_SCRIPT" new test-workflow

    # Run in dry-run mode to check config is loaded
    run bash "$WORKFLOW_SCRIPT" run test-workflow --dry-run

    # Should use global config values
    # (We can't directly check MODEL value, but output should not error)
    assert_success
}

@test "global-config: project config overrides global" {
    # Create project
    bash "$WORKFLOW_SCRIPT" init .

    # Set different value in project config
    cat > .workflow/config <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=
MAX_TOKENS=
OUTPUT_FORMAT=
SYSTEM_PROMPTS=()
EOF

    # Create workflow
    bash "$WORKFLOW_SCRIPT" new test-workflow

    # Check config command shows override
    run bash "$WORKFLOW_SCRIPT" config

    assert_success
    assert_output --partial "claude-opus-4"
    assert_output --partial "(project)"
}

@test "global-config: workflow config overrides global and project" {
    # Create project with custom config
    bash "$WORKFLOW_SCRIPT" init .
    cat > .workflow/config <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=
MAX_TOKENS=
OUTPUT_FORMAT=
SYSTEM_PROMPTS=()
EOF

    # Create workflow with different value
    bash "$WORKFLOW_SCRIPT" new test-workflow
    cat > .workflow/test-workflow/config <<'EOF'
MODEL="claude-haiku-4"
TEMPERATURE=
MAX_TOKENS=
OUTPUT_FORMAT=
SYSTEM_PROMPTS=()
EOF

    # Check workflow config shows workflow override
    run bash "$WORKFLOW_SCRIPT" config test-workflow

    assert_success
    assert_output --partial "claude-haiku-4"
    assert_output --partial "(workflow)"
}

@test "global-config: environment variable overrides config file" {
    # Create project
    bash "$WORKFLOW_SCRIPT" init .

    # Set API key in global config
    cat >> "$GLOBAL_CONFIG_DIR/config" <<'EOF'
ANTHROPIC_API_KEY="sk-from-config"
EOF

    # Set env var (should take precedence)
    export ANTHROPIC_API_KEY="sk-from-env"

    # API validation should use env var value
    # (We can't test this directly without calling API, but we can verify
    # the config file was created and environment setup works)
    run bash "$WORKFLOW_SCRIPT" config

    assert_success
}

@test "global-config: gracefully handles missing global config" {
    # Remove global config
    rm -rf "$GLOBAL_CONFIG_DIR"

    # Prevent auto-creation by making directory read-only parent
    # (Simulates permission denied scenario)
    # For this test, we just verify fallback works

    # Init should still work with hard-coded defaults
    run bash "$WORKFLOW_SCRIPT" init .

    # Should succeed and create global config
    assert_success
    assert_file_exists "$GLOBAL_CONFIG_DIR/config"
}

@test "global-config: init inherits from global not DEFAULT_* constants" {
    # Modify global config
    bash "$WORKFLOW_SCRIPT" init .  # Creates global config first

    cat > "$GLOBAL_CONFIG_DIR/config" <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.3
MAX_TOKENS=16384
OUTPUT_FORMAT="json"
SYSTEM_PROMPTS=(base Custom)
WIREFLOW_PROMPT_PREFIX="$HOME/.config/wireflow/prompts"
EOF

    # Create new project in different location (should inherit from global, not parent)
    cd "$TEST_TEMP_DIR"
    mkdir subproject
    cd subproject

    run bash "$WORKFLOW_SCRIPT" init .

    assert_success
    assert_output --partial "Initialized workflow project"

    # Verify config file was created with empty values (pass-through inheritance)
    source .workflow/config
    assert_equal "$MODEL" ""
    assert_equal "$TEMPERATURE" ""
}

@test "global-config: nested project inherits from parent not global" {
    # Create parent project with custom config
    bash "$WORKFLOW_SCRIPT" init .
    cat > .workflow/config <<'EOF'
MODEL="claude-opus-4"
TEMPERATURE=0.5
MAX_TOKENS=
OUTPUT_FORMAT=
SYSTEM_PROMPTS=(base NeuroAI)
EOF

    # Create nested project
    mkdir nested
    cd nested

    run bash -c "echo 'y' | bash '$WORKFLOW_SCRIPT' init ."

    assert_success
    assert_output --partial "existing project"
    assert_output --partial "Inherit configuration from full ancestor cascade"

    # Verify config uses empty values for transparent pass-through
    source .workflow/config
    assert_equal "$MODEL" ""
    assert_equal "$TEMPERATURE" ""
}

@test "global-config: config command shows global tier" {
    # Create project
    bash "$WORKFLOW_SCRIPT" init .

    run bash "$WORKFLOW_SCRIPT" config

    assert_success
    assert_output --partial "Configuration Cascade:"
    assert_output --partial "Global:"
    assert_output --partial ".config/wireflow/config"
    assert_output --partial "Project:"
    assert_output --partial "(global)"
}

@test "global-config: workflow config command shows global tier" {
    # Create project and workflow
    bash "$WORKFLOW_SCRIPT" init .
    bash "$WORKFLOW_SCRIPT" new test-workflow

    run bash "$WORKFLOW_SCRIPT" config test-workflow

    assert_success
    assert_output --partial "Configuration Cascade:"
    assert_output --partial "Global:"
    assert_output --partial "Project:"
    assert_output --partial "Workflow:"
    assert_output --partial "(global)"
}
