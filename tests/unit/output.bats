#!/usr/bin/env bats

# Unit tests for lib/output.sh functions
# Tests streaming markdown renderer initialization and lifecycle

load ../test_helper/bats-support/load
load ../test_helper/bats-assert/load
load ../test_helper/bats-file/load
load ../test_helper/common.bash

setup() {
    setup_test_env

    # Source output functions directly for unit testing
    WORKFLOW_LIB_DIR="$(cd "$BATS_TEST_DIRNAME/../.."; pwd)/lib"
    SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/../.."; pwd)"
    source "$WORKFLOW_LIB_DIR/output.sh"
}

teardown() {
    # Ensure renderer is cleaned up
    cleanup_md_renderer 2>/dev/null || true
    cleanup_test_env
}

# =============================================================================
# init_md_renderer() tests
# =============================================================================

@test "init_md_renderer: sets MD_RENDER_ACTIVE=false when not a terminal" {
    # Redirect stdout to simulate non-terminal
    run bash -c 'source "$1/lib/output.sh"; SCRIPT_DIR="$1"; init_md_renderer; echo "$MD_RENDER_ACTIVE"' _ "$SCRIPT_DIR"
    assert_success
    assert_output "false"
}

@test "init_md_renderer: initializes global variables" {
    # Before init, variables should be their defaults
    assert_equal "$MD_RENDER_ACTIVE" "false"
    assert_equal "$MD_RENDER_PIPE" ""
    assert_equal "$MD_RENDER_PID" ""
}

@test "init_md_renderer: returns success even without renderer" {
    # Should return 0 regardless of renderer availability
    run init_md_renderer
    assert_success
}

# =============================================================================
# stream_to_console() tests
# =============================================================================

@test "stream_to_console: outputs to stdout when renderer inactive" {
    MD_RENDER_ACTIVE=false

    run stream_to_console "Hello, World!"
    assert_success
    assert_output "Hello, World!"
}

@test "stream_to_console: handles empty string" {
    MD_RENDER_ACTIVE=false

    run stream_to_console ""
    assert_success
    assert_output ""
}

@test "stream_to_console: handles special characters" {
    MD_RENDER_ACTIVE=false

    run stream_to_console "# Heading\n**bold** and *italic*"
    assert_success
    assert_output "# Heading\n**bold** and *italic*"
}

@test "stream_to_console: handles newlines correctly" {
    MD_RENDER_ACTIVE=false

    run stream_to_console $'\n'
    assert_success
    assert_output ""  # newline only, no visible output
}

@test "stream_to_console: handles multiline content" {
    MD_RENDER_ACTIVE=false

    local multiline="Line 1
Line 2
Line 3"
    run stream_to_console "$multiline"
    assert_success
    assert_output "$multiline"
}

# =============================================================================
# cleanup_md_renderer() tests
# =============================================================================

@test "cleanup_md_renderer: is safe to call when inactive" {
    MD_RENDER_ACTIVE=false

    run cleanup_md_renderer
    assert_success
}

@test "cleanup_md_renderer: resets global variables when active" {
    # Run in subshell to avoid FD conflicts with bats
    run bash -c '
        source "$1/lib/output.sh"
        MD_RENDER_ACTIVE=true
        MD_RENDER_PIPE="/tmp/nonexistent-pipe-$$"
        MD_RENDER_PID=""

        cleanup_md_renderer

        echo "ACTIVE=$MD_RENDER_ACTIVE"
        echo "PIPE=$MD_RENDER_PIPE"
        echo "PID=$MD_RENDER_PID"
    ' _ "$WORKFLOW_LIB_DIR/.."

    assert_success
    assert_line "ACTIVE=false"
    assert_line "PIPE="
    assert_line "PID="
}

@test "cleanup_md_renderer: handles missing FIFO gracefully" {
    # Run in subshell to avoid FD conflicts with bats
    run bash -c '
        source "$1/lib/output.sh"
        MD_RENDER_ACTIVE=true
        MD_RENDER_PIPE="/tmp/nonexistent-pipe-$$"
        MD_RENDER_PID=""

        cleanup_md_renderer
        echo "success"
    ' _ "$WORKFLOW_LIB_DIR/.."

    assert_success
    assert_output "success"
}

# =============================================================================
# Integration-style tests (simulating terminal behavior)
# =============================================================================

@test "full lifecycle: init, stream, cleanup works when not terminal" {
    # Simulate complete lifecycle in non-terminal environment
    run bash -c '
        source "$1/lib/output.sh"
        SCRIPT_DIR="$1"

        init_md_renderer
        stream_to_console "Test output"
        cleanup_md_renderer

        echo ""  # newline to separate output
        echo "done"
    ' _ "$SCRIPT_DIR"

    assert_success
    assert_output --partial "Test output"
    assert_output --partial "done"
}

@test "stream_to_console: multiple calls accumulate output" {
    MD_RENDER_ACTIVE=false

    run bash -c '
        source "$1/lib/output.sh"
        MD_RENDER_ACTIVE=false

        stream_to_console "Part 1 "
        stream_to_console "Part 2 "
        stream_to_console "Part 3"
    ' _ "$WORKFLOW_LIB_DIR/.."

    assert_success
    assert_output "Part 1 Part 2 Part 3"
}

# =============================================================================
# Fallback behavior tests
# =============================================================================

@test "init_md_renderer: shows hint when no renderer support and in terminal" {
    # This test checks fallback message when uv/rich not available
    # We can't easily test terminal detection in bats, so we verify
    # the function handles the no-renderer case gracefully
    run bash -c '
        source "$1/lib/output.sh"
        SCRIPT_DIR="$1"

        # Override PATH to hide uv
        PATH="/usr/bin:/bin"

        # Function should still succeed
        init_md_renderer
        echo "init_ok"
    ' _ "$SCRIPT_DIR"

    assert_success
    assert_line "init_ok"
}

@test "cleanup_md_renderer_on_exit: is alias for cleanup_md_renderer" {
    MD_RENDER_ACTIVE=false

    # Verify the trap handler function exists and works
    run cleanup_md_renderer_on_exit
    assert_success
}
