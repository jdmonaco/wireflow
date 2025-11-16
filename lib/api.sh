# =============================================================================
# Workflow API Functions
# =============================================================================
# API interaction layer for workflow CLI tool.
# Currently supports Anthropic Messages API.
# Future: Support for OpenAI, Mistral, local models, etc.
# =============================================================================

# Source utility functions if not already loaded
SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
if ! declare -f escape_json > /dev/null; then
    source "$SCRIPT_LIB_DIR/utils.sh"
fi

# =============================================================================
# Anthropic Provider Implementation
# =============================================================================

# Validate Anthropic API configuration
# Args:
#   $1 - API key (optional, uses ANTHROPIC_API_KEY env var if not provided)
# Returns:
#   0 - Valid configuration
#   1 - Missing or invalid API key
anthropic_validate() {
    local api_key="${1:-$ANTHROPIC_API_KEY}"

    # Check if empty string was explicitly passed
    if [[ $# -gt 0 && -z "$1" ]]; then
        echo "Error: ANTHROPIC_API_KEY environment variable is not set" >&2
        return 1
    fi

    if [[ -z "$api_key" ]]; then
        echo "Error: ANTHROPIC_API_KEY environment variable is not set" >&2
        return 1
    fi

    return 0
}

# Execute Anthropic Messages API request in single mode
# Single mode = one complete request/response cycle (NOT batch processing)
# Blocks until response received, then displays with less
#
# Args:
#   All arguments are key=value pairs:
#   api_key=...        - Anthropic API key
#   model=...          - Model name (e.g., "claude-sonnet-4-5")
#   max_tokens=...     - Maximum tokens to generate
#   temperature=...    - Temperature (0.0-1.0)
#   system_prompt=...  - JSON-escaped system prompt
#   user_prompt=...    - JSON-escaped user prompt
#   output_file=...    - Path to write response
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
#
# Side effects:
#   Writes to output_file
#   Displays response with less
#   Outputs progress messages to stdout
anthropic_execute_single() {
    # Parse key=value arguments into associative array
    local -A params
    while [[ $# -gt 0 ]]; do
        IFS='=' read -r key value <<< "$1"
        params["$key"]="$value"
        shift
    done

    # Build JSON payload
    local json_payload
    json_payload=$(cat <<EOF
{
  "model": "${params[model]}",
  "max_tokens": ${params[max_tokens]},
  "temperature": ${params[temperature]},
  "system": ${params[system_prompt]},
  "messages": [
    {
      "role": "user",
      "content": ${params[user_prompt]}
    }
  ]
}
EOF
)

    # Execute request
    echo -n "Sending Messages API request... "

    local response
    response=$(curl -s https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$json_payload")

    echo "done!"

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:"
        echo "$response" | jq '.error'
        return 1
    fi

    # Extract and save response
    echo "$response" | jq -r '.content[0].text' > "${params[output_file]}"

    # Display with less
    less "${params[output_file]}"

    return 0
}

# Execute Anthropic Messages API request in streaming mode
# Streams response in real-time using Server-Sent Events (SSE)
#
# Args:
#   All arguments are key=value pairs (same as anthropic_execute_single):
#   api_key, model, max_tokens, temperature
#   system_prompt, user_prompt, output_file
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
#
# Side effects:
#   Writes to output_file
#   Outputs streaming text to stdout in real-time
#   Outputs progress messages
anthropic_execute_stream() {
    # Parse key=value arguments into associative array
    local -A params
    while [[ $# -gt 0 ]]; do
        IFS='=' read -r key value <<< "$1"
        params["$key"]="$value"
        shift
    done

    # Build JSON payload
    local json_payload
    json_payload=$(cat <<EOF
{
  "model": "${params[model]}",
  "max_tokens": ${params[max_tokens]},
  "temperature": ${params[temperature]},
  "system": ${params[system_prompt]},
  "messages": [
    {
      "role": "user",
      "content": ${params[user_prompt]}
    }
  ]
}
EOF
)

    # Add streaming flag to payload
    json_payload=$(echo "$json_payload" | jq '. + {stream: true}')

    # Execute streaming request
    echo "Sending Messages API request (streaming)..."
    echo "---"
    echo ""

    # Initialize output file
    > "${params[output_file]}"

    # Use error flag file to communicate from pipeline subshell
    local error_flag="$(mktemp)"
    rm "$error_flag"  # Remove, we'll create it if error occurs

    # Stream response and parse SSE events
    curl -Ns https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: ${params[api_key]}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$json_payload" | while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Parse SSE format (lines start with "data: ")
        if [[ "$line" == data:* ]]; then
            json_data="${line#data: }"

            # Skip ping events
            [[ "$json_data" == "[DONE]" ]] && continue

            # Extract event type
            event_type=$(echo "$json_data" | jq -r '.type // empty')

            case "$event_type" in
                "content_block_delta")
                    # Extract and print text incrementally
                    delta_text=$(echo "$json_data" | jq -r '.delta.text // empty')
                    if [[ -n "$delta_text" ]]; then
                        printf '%s' "$delta_text"
                        printf '%s' "$delta_text" >> "${params[output_file]}"
                    fi
                    ;;
                "message_stop")
                    printf '\n'
                    ;;
                "error")
                    echo ""
                    echo "API Error:"
                    echo "$json_data" | jq '.error'
                    touch "$error_flag"  # Signal error
                    exit 1
                    ;;
            esac
        fi
    done

    # Check if error occurred in pipeline
    if [[ -f "$error_flag" ]]; then
        rm -f "$error_flag"
        return 1
    fi

    echo ""
    echo "---"

    return 0
}
