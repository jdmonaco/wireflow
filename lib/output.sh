# =============================================================================
# Output Module - Streaming Markdown Renderer Integration
# =============================================================================
# Provides functions to manage the streaming markdown renderer for terminal
# output. When output is to a terminal, streams through bin/md-render for
# rich formatting. When piped or redirected, passes through raw markdown.
# =============================================================================

# Global state for renderer management
MD_RENDER_ACTIVE=false
MD_RENDER_PIPE=""
MD_RENDER_PID=""

# Initialize markdown renderer if stdout is a terminal
# Sets up FIFO pipe and backgrounds the renderer process
# Falls back gracefully if renderer dependencies unavailable
#
# Returns:
#   Sets MD_RENDER_ACTIVE=true if renderer is active
#   Sets MD_RENDER_PIPE to FIFO path
#   Sets MD_RENDER_PID to renderer process ID
init_md_renderer() {
    MD_RENDER_ACTIVE=false
    MD_RENDER_PIPE=""
    MD_RENDER_PID=""

    # Only render when stdout is a terminal
    if [[ ! -t 1 ]]; then
        return 0
    fi

    # Locate the renderer script
    local renderer="${SCRIPT_DIR}/bin/md-render"
    if [[ ! -x "$renderer" ]]; then
        # Renderer not found - fall back to raw output
        return 0
    fi

    # Check for uv (preferred) or python3 with rich
    if command -v uv &>/dev/null; then
        # uv handles dependency installation automatically
        :
    elif python3 -c "import rich" 2>/dev/null; then
        # python3 with rich available - will work
        :
    else
        # No renderer support - show one-time hint and fall back
        echo "[tip: install 'uv' for formatted markdown output]" >&2
        return 0
    fi

    # Create FIFO for renderer input
    MD_RENDER_PIPE=$(mktemp -u)
    if ! mkfifo "$MD_RENDER_PIPE" 2>/dev/null; then
        MD_RENDER_PIPE=""
        return 0
    fi

    # Start renderer in background, reading from FIFO
    "$renderer" < "$MD_RENDER_PIPE" &
    MD_RENDER_PID=$!
    MD_RENDER_ACTIVE=true

    # Open FIFO for writing (keeps it open for multiple writes)
    exec 3>"$MD_RENDER_PIPE"
}

# Write text to console output
# Routes through renderer if active, otherwise direct to stdout
#
# Arguments:
#   $1 - Text to output (may contain special characters)
#
# Usage:
#   stream_to_console "$delta_text"
stream_to_console() {
    local text="$1"
    if [[ "$MD_RENDER_ACTIVE" == "true" ]]; then
        # Write to renderer via FIFO
        printf '%s' "$text" >&3
    else
        # Direct to stdout
        printf '%s' "$text"
    fi
}

# Cleanup renderer process and FIFO
# Should be called after streaming completes
#
# Handles:
#   - Closing FIFO write end (signals EOF to renderer)
#   - Waiting for renderer to finish
#   - Removing FIFO file
cleanup_md_renderer() {
    if [[ "$MD_RENDER_ACTIVE" == "true" ]]; then
        # Close write end of FIFO (signals EOF to renderer)
        # Only close if FD 3 is actually open (check /dev/fd/3)
        if [[ -e /dev/fd/3 ]]; then
            exec 3>&-
        fi

        # Wait for renderer to finish processing
        if [[ -n "$MD_RENDER_PID" ]]; then
            wait "$MD_RENDER_PID" 2>/dev/null || true
        fi

        # Remove FIFO
        if [[ -n "$MD_RENDER_PIPE" && -p "$MD_RENDER_PIPE" ]]; then
            rm -f "$MD_RENDER_PIPE"
        fi

        MD_RENDER_ACTIVE=false
        MD_RENDER_PIPE=""
        MD_RENDER_PID=""
    fi
}

# Trap handler for cleanup on script exit or interrupt
# Call this to ensure renderer cleanup on Ctrl+C or errors
#
# Usage:
#   trap cleanup_md_renderer_on_exit EXIT INT TERM
cleanup_md_renderer_on_exit() {
    cleanup_md_renderer
}

# =============================================================================
# Pager Display
# =============================================================================

# Display file in appropriate pager based on file type and available tools
# Arguments:
#   $1 - file_path: Path to file to display
# Returns:
#   0 on success, 1 if file doesn't exist
# Pager priority:
#   - Markdown: glow -p > gum pager > $PAGER > less
#   - Other text: gum pager > $PAGER > less
display_in_pager() {
    local file_path="$1"

    [[ ! -f "$file_path" ]] && return 1
    [[ ! -t 1 ]] && return 0  # Skip if not interactive terminal

    local ext="${file_path##*.}"

    if [[ "$ext" == "md" ]]; then
        # Markdown file - prefer glow for rendering
        if command -v glow >/dev/null 2>&1; then
            glow -p "$file_path"
            return 0
        fi
    fi

    # gum pager works for any text file
    if command -v gum >/dev/null 2>&1; then
        gum pager < "$file_path"
        return 0
    fi

    # Fall back to $PAGER or less
    if [[ -n "$PAGER" ]]; then
        "$PAGER" "$file_path"
    elif command -v less >/dev/null 2>&1; then
        less "$file_path"
    else
        # No pager available, just cat
        cat "$file_path"
    fi

    return 0
}
