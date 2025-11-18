# =============================================================================
# Workflow Execution Functions
# =============================================================================
# Shared execution logic for run and task modes.
# Houses common functions for system prompt building, context aggregation,
# token estimation, dry-run handling, and API request execution.
# This file is sourced by workflow.sh and lib/task.sh.
# =============================================================================

# =============================================================================
# System Prompt Building
# =============================================================================

# Build system prompt from SYSTEM_PROMPTS configuration array
# Concatenates prompt files from WORKFLOW_PROMPT_PREFIX directory
#
# Args:
#   $1 - system_prompt_file: Path where composed prompt should be saved
# Requires:
#   WORKFLOW_PROMPT_PREFIX: Directory containing *.txt prompt files
#   SYSTEM_PROMPTS: Array of prompt names (without .txt extension)
# Returns:
#   0 on success, 1 on error
# Side effects:
#   Writes composed prompt to system_prompt_file
#   May use cached version if rebuild fails
build_system_prompt() {
    local system_prompt_file="$1"

    # Validate prompt directory configuration
    if [[ -z "$WORKFLOW_PROMPT_PREFIX" ]]; then
        echo "Error: WORKFLOW_PROMPT_PREFIX environment variable is not set" >&2
        echo "Set WORKFLOW_PROMPT_PREFIX to the directory containing your *.txt prompt files" >&2
        return 1
    fi

    if [[ ! -d "$WORKFLOW_PROMPT_PREFIX" ]]; then
        echo "Error: System prompt directory not found: $WORKFLOW_PROMPT_PREFIX" >&2
        return 1
    fi

    echo "Building system prompt from: ${SYSTEM_PROMPTS[*]}"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$system_prompt_file")"

    # Build to temp file for atomic write
    local temp_prompt
    temp_prompt=$(mktemp)
    local build_success=true

    # Concatenate all specified prompts
    for prompt_name in "${SYSTEM_PROMPTS[@]}"; do
        local prompt_file="$WORKFLOW_PROMPT_PREFIX/${prompt_name}.txt"
        if [[ ! -f "$prompt_file" ]]; then
            echo "Error: System prompt file not found: $prompt_file" >&2
            build_success=false
            break
        fi
        cat "$prompt_file" >> "$temp_prompt"
    done

    # Handle build result
    if [[ "$build_success" == true ]]; then
        mv "$temp_prompt" "$system_prompt_file"
        echo "System prompt built successfully"
        return 0
    else
        rm -f "$temp_prompt"
        # Fall back to cached version if available
        if [[ -f "$system_prompt_file" ]]; then
            echo "Warning: Using cached system prompt (rebuild failed)" >&2
            return 0
        else
            echo "Error: Cannot build system prompt and no cached version available" >&2
            return 1
        fi
    fi
}
