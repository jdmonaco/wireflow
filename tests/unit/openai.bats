#!/usr/bin/env bats

# Unit tests for lib/openai.sh functions
# Tests OpenAI-compatible API functions

load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

setup() {
    setup_test_env

    # Source required libraries for unit testing
    WORKFLOW_LIB_DIR="$(cd "$BATS_TEST_DIRNAME/../.."; pwd)/lib"
    source "$WORKFLOW_LIB_DIR/utils.sh"
    source "$WORKFLOW_LIB_DIR/config.sh"
    source "$WORKFLOW_LIB_DIR/openai.sh"
}

teardown() {
    cleanup_test_env
}

# =============================================================================
# openai_validate() tests
# =============================================================================

@test "openai_validate: fails when OPENAI_BASE_URL is not set" {
    unset OPENAI_BASE_URL

    run openai_validate
    assert_failure
    assert_output --partial "OPENAI_BASE_URL is not set"
}

@test "openai_validate: fails with invalid URL protocol" {
    OPENAI_BASE_URL="ftp://localhost:1234/v1"

    run openai_validate
    assert_failure
    assert_output --partial "must start with http:// or https://"
}

@test "openai_validate: succeeds with http URL" {
    OPENAI_BASE_URL="http://localhost:1234/v1"

    run openai_validate
    assert_success
}

@test "openai_validate: succeeds with https URL" {
    OPENAI_BASE_URL="https://api.example.com/v1"

    run openai_validate
    assert_success
}

@test "openai_validate: strips trailing slash from URL" {
    OPENAI_BASE_URL="http://localhost:1234/v1/"

    openai_validate

    # After validation, trailing slash should be removed
    [[ "$OPENAI_BASE_URL" == "http://localhost:1234/v1" ]]
}

# =============================================================================
# openai_resolve_model() tests
# =============================================================================

@test "openai_resolve_model: uses OPENAI_MODEL when set" {
    OPENAI_MODEL="my-explicit-model"
    OPENAI_MODEL_BALANCED="default-model"

    run openai_resolve_model "balanced"
    assert_success
    assert_output "my-explicit-model"
}

@test "openai_resolve_model: uses OPENAI_MODEL_FAST for fast profile" {
    OPENAI_MODEL=""
    OPENAI_MODEL_FAST="fast-model"

    run openai_resolve_model "fast"
    assert_success
    assert_output "fast-model"
}

@test "openai_resolve_model: uses OPENAI_MODEL_BALANCED for balanced profile" {
    OPENAI_MODEL=""
    OPENAI_MODEL_BALANCED="balanced-model"

    run openai_resolve_model "balanced"
    assert_success
    assert_output "balanced-model"
}

@test "openai_resolve_model: uses OPENAI_MODEL_DEEP for deep profile" {
    OPENAI_MODEL=""
    OPENAI_MODEL_DEEP="deep-model"

    run openai_resolve_model "deep"
    assert_success
    assert_output "deep-model"
}

@test "openai_resolve_model: fails when profile model not configured" {
    OPENAI_MODEL=""
    OPENAI_MODEL_FAST=""

    run openai_resolve_model "fast"
    assert_failure
    assert_output --partial "OPENAI_MODEL_FAST is not configured"
}

@test "openai_resolve_model: fails for unknown profile" {
    run openai_resolve_model "unknown"
    assert_failure
    assert_output --partial "Unknown profile"
}

# =============================================================================
# openai_check_feature() tests
# =============================================================================

@test "openai_check_feature: warns for thinking feature" {
    run openai_check_feature "thinking"
    assert_failure
    assert_output --partial "Extended thinking is not supported"
}

@test "openai_check_feature: warns for effort feature" {
    run openai_check_feature "effort"
    assert_failure
    assert_output --partial "Effort parameter is not supported"
}

@test "openai_check_feature: warns for citations feature" {
    run openai_check_feature "citations"
    assert_failure
    assert_output --partial "Citations are not supported"
}

@test "openai_check_feature: errors for batch feature" {
    run openai_check_feature "batch"
    assert_failure
    assert_output --partial "Batch API is not supported"
}

@test "openai_check_feature: returns failure for pdf feature" {
    run openai_check_feature "pdf"
    assert_failure
    # No warning message for PDF (handled at conversion time)
}

@test "openai_check_feature: returns failure for cache feature silently" {
    run openai_check_feature "cache"
    assert_failure
    # Should not output a warning for cache
    refute_output --partial "Warning"
}

@test "openai_check_feature: returns success for unknown features" {
    run openai_check_feature "unknown_feature"
    assert_success
}

# =============================================================================
# convert_to_openai_messages() tests
# =============================================================================

@test "convert_to_openai_messages: converts system text blocks" {
    local system_file="$TEST_TEMP_DIR/system.json"
    local user_file="$TEST_TEMP_DIR/user.json"

    echo '[{"type": "text", "text": "You are a helpful assistant."}]' > "$system_file"
    echo '[{"type": "text", "text": "Hello, world!"}]' > "$user_file"

    run convert_to_openai_messages "$system_file" "$user_file"
    assert_success

    # Check system message
    echo "$output" | jq -e '.[0].role == "system"'
    echo "$output" | jq -e '.[0].content | contains("helpful assistant")'

    # Check user message
    echo "$output" | jq -e '.[1].role == "user"'
    echo "$output" | jq -e '.[1].content | contains("Hello")'
}

@test "convert_to_openai_messages: concatenates multiple system blocks" {
    local system_file="$TEST_TEMP_DIR/system.json"
    local user_file="$TEST_TEMP_DIR/user.json"

    echo '[{"type": "text", "text": "First."}, {"type": "text", "text": "Second."}]' > "$system_file"
    echo '[{"type": "text", "text": "User message"}]' > "$user_file"

    run convert_to_openai_messages "$system_file" "$user_file"
    assert_success

    # System content should contain both texts
    echo "$output" | jq -e '.[0].content | contains("First")'
    echo "$output" | jq -e '.[0].content | contains("Second")'
}

@test "convert_to_openai_messages: converts image blocks" {
    local system_file="$TEST_TEMP_DIR/system.json"
    local user_file="$TEST_TEMP_DIR/user.json"

    echo '[{"type": "text", "text": "System."}]' > "$system_file"
    cat > "$user_file" <<'EOF'
[
  {"type": "text", "text": "Look at this image:"},
  {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": "iVBORw0KGgo="}}
]
EOF

    run convert_to_openai_messages "$system_file" "$user_file"
    assert_success

    # User content should be an array (multimodal)
    echo "$output" | jq -e '.[1].content | type == "array"'

    # Check image_url format
    echo "$output" | jq -e '.[1].content[1].type == "image_url"'
    echo "$output" | jq -e '.[1].content[1].image_url.url | startswith("data:image/png;base64,")'
}

@test "convert_to_openai_messages: strips cache_control from text blocks" {
    local system_file="$TEST_TEMP_DIR/system.json"
    local user_file="$TEST_TEMP_DIR/user.json"

    echo '[{"type": "text", "text": "System."}]' > "$system_file"
    echo '[{"type": "text", "text": "User.", "cache_control": {"type": "ephemeral"}}]' > "$user_file"

    run convert_to_openai_messages "$system_file" "$user_file"
    assert_success

    # Output should not contain cache_control
    refute_output --partial "cache_control"
}

@test "convert_to_openai_messages: handles empty system blocks" {
    local system_file="$TEST_TEMP_DIR/system.json"
    local user_file="$TEST_TEMP_DIR/user.json"

    echo '[]' > "$system_file"
    echo '[{"type": "text", "text": "User message"}]' > "$user_file"

    run convert_to_openai_messages "$system_file" "$user_file"
    assert_success

    # Should only have user message (no empty system message)
    local msg_count
    msg_count=$(echo "$output" | jq 'length')
    [[ "$msg_count" == "1" ]]
    echo "$output" | jq -e '.[0].role == "user"'
}

@test "convert_to_openai_messages: warns for document blocks" {
    local system_file="$TEST_TEMP_DIR/system.json"
    local user_file="$TEST_TEMP_DIR/user.json"

    echo '[{"type": "text", "text": "System."}]' > "$system_file"
    echo '[{"type": "document", "source": {"type": "base64", "media_type": "application/pdf", "data": "..."}}]' > "$user_file"

    run convert_to_openai_messages "$system_file" "$user_file"
    assert_success
    assert_output --partial "Document blocks are not supported"
}
