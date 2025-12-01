# =============================================================================
# OpenAI-Compatible API Functions
# =============================================================================
# API interaction layer for OpenAI-compatible endpoints.
# Supports LM Studio, ollama, vLLM, and other OpenAI-compatible servers.
# =============================================================================

# =============================================================================
# OpenAI Provider Implementation
# =============================================================================

# Validate OpenAI-compatible API configuration
# Args:
#   None (uses global config variables)
# Returns:
#   0 - Valid configuration
#   1 - Missing or invalid configuration
openai_validate() {
    if [[ -z "$OPENAI_BASE_URL" ]]; then
        echo "Error: OPENAI_BASE_URL is not set" >&2
        echo "Set it in your config file or environment, e.g.:" >&2
        echo "  OPENAI_BASE_URL=\"http://localhost:1234/v1\"" >&2
        return 1
    fi

    # Ensure URL doesn't have trailing slash
    OPENAI_BASE_URL="${OPENAI_BASE_URL%/}"

    # Basic URL validation
    if [[ ! "$OPENAI_BASE_URL" =~ ^https?:// ]]; then
        echo "Error: OPENAI_BASE_URL must start with http:// or https://" >&2
        return 1
    fi

    return 0
}

# List available models from OpenAI-compatible server
# Args:
#   None (uses global config variables)
# Returns:
#   0 - Success (outputs model list JSON)
#   1 - API error or network failure
openai_list_models() {
    if ! openai_validate; then
        return 1
    fi

    local response
    response=$(curl -s "${OPENAI_BASE_URL}/models" \
        -H "Authorization: Bearer ${OPENAI_API_KEY:-lm-studio}" \
        -H "Content-Type: application/json")

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:" >&2
        echo "$response" | jq '.error' >&2
        return 1
    fi

    echo "$response"
    return 0
}

# Convert Anthropic-style content blocks to OpenAI message format
# Reads from files and outputs OpenAI messages array
# Args:
#   $1 - Path to system blocks file (JSON array)
#   $2 - Path to user blocks file (JSON array)
# Outputs:
#   JSON array of OpenAI-format messages
convert_to_openai_messages() {
    local system_blocks_file="$1"
    local user_blocks_file="$2"

    local system_blocks
    local user_blocks
    system_blocks=$(<"$system_blocks_file")
    user_blocks=$(<"$user_blocks_file")

    # Build messages array
    local messages="[]"

    # Convert system blocks to single system message
    # Anthropic: [{"type": "text", "text": "..."}]
    # OpenAI: {"role": "system", "content": "..."}
    local system_text
    system_text=$(echo "$system_blocks" | jq -r '[.[] | select(.type == "text") | .text] | join("\n\n")')

    if [[ -n "$system_text" && "$system_text" != "null" ]]; then
        messages=$(echo "$messages" | jq --arg text "$system_text" '. += [{"role": "system", "content": $text}]')
    fi

    # Convert user blocks to user message
    # Anthropic blocks can be text, image, or document (PDF - should be converted to images before calling)
    # OpenAI: {"role": "user", "content": [...]} or {"role": "user", "content": "..."}

    local user_content="[]"
    local num_blocks
    num_blocks=$(echo "$user_blocks" | jq 'length')

    for ((i=0; i<num_blocks; i++)); do
        local block
        block=$(echo "$user_blocks" | jq ".[$i]")

        local block_type
        block_type=$(echo "$block" | jq -r '.type')

        case "$block_type" in
            text)
                # Text block - convert directly
                # Remove cache_control if present (OpenAI doesn't support it)
                local text_content
                text_content=$(echo "$block" | jq '{type: "text", text: .text}')
                user_content=$(echo "$user_content" | jq ". += [$text_content]")
                ;;
            image)
                # Image block - convert format
                # Anthropic: {"type": "image", "source": {"type": "base64", "media_type": "...", "data": "..."}}
                # OpenAI: {"type": "image_url", "image_url": {"url": "data:mime;base64,..."}}
                local media_type
                media_type=$(echo "$block" | jq -r '.source.media_type')
                local base64_data
                base64_data=$(echo "$block" | jq -r '.source.data')

                local image_content
                image_content=$(jq -n \
                    --arg media_type "$media_type" \
                    --arg data "$base64_data" \
                    '{type: "image_url", image_url: {url: ("data:" + $media_type + ";base64," + $data)}}')
                user_content=$(echo "$user_content" | jq ". += [$image_content]")
                ;;
            document)
                # Document blocks should have been converted to images before this point
                # If we still get one, warn and skip
                echo "Warning: Document blocks are not supported by OpenAI API - skipping" >&2
                ;;
            *)
                # Unknown block type - try to pass through as text if it has text field
                local text_field
                text_field=$(echo "$block" | jq -r '.text // empty')
                if [[ -n "$text_field" ]]; then
                    local fallback_content
                    fallback_content=$(jq -n --arg text "$text_field" '{type: "text", text: $text}')
                    user_content=$(echo "$user_content" | jq ". += [$fallback_content]")
                fi
                ;;
        esac
    done

    # Determine if we can use simple string content or need array
    local content_count
    content_count=$(echo "$user_content" | jq 'length')
    local has_images
    has_images=$(echo "$user_content" | jq '[.[] | select(.type == "image_url")] | length > 0')

    if [[ "$has_images" == "true" || $content_count -gt 1 ]]; then
        # Use array format for multimodal content
        messages=$(echo "$messages" | jq --argjson content "$user_content" '. += [{"role": "user", "content": $content}]')
    elif [[ $content_count -eq 1 ]]; then
        # Single text block - use simple string format
        local simple_text
        simple_text=$(echo "$user_content" | jq -r '.[0].text')
        messages=$(echo "$messages" | jq --arg text "$simple_text" '. += [{"role": "user", "content": $text}]')
    fi

    echo "$messages"
}

# Execute OpenAI-compatible API request in single (non-streaming) mode
# Args:
#   All arguments are key=value pairs:
#   model=...                - Model name
#   max_tokens=...           - Maximum tokens to generate
#   temperature=...          - Temperature (0.0-2.0)
#   system_blocks_file=...   - Path to file containing JSON array of system content blocks
#   user_blocks_file=...     - Path to file containing JSON array of user content blocks
#   output_file=...          - Path to write response
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
openai_execute_single() {
    # Parse key=value arguments into associative array
    local -A params
    while [[ $# -gt 0 ]]; do
        IFS='=' read -r key value <<< "$1"
        params["$key"]="$value"
        shift
    done

    # Validate configuration
    if ! openai_validate; then
        return 1
    fi

    # Convert messages to OpenAI format
    local messages
    messages=$(convert_to_openai_messages "${params[system_blocks_file]}" "${params[user_blocks_file]}")

    # Build JSON payload
    local json_payload
    json_payload=$(jq -n \
        --arg model "${params[model]}" \
        --argjson max_tokens "${params[max_tokens]}" \
        --argjson temperature "${params[temperature]}" \
        --argjson messages "$messages" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            messages: $messages,
            stream: false
        }')

    # Execute request
    echo -n "Sending OpenAI-compatible API request... "

    local response
    response=$(echo "$json_payload" | curl -s "${OPENAI_BASE_URL}/chat/completions" \
        -H "Authorization: Bearer ${OPENAI_API_KEY:-lm-studio}" \
        -H "Content-Type: application/json" \
        -d @-)

    echo "done!"

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:" >&2
        echo "$response" | jq '.error' >&2
        return 1
    fi

    # Extract content from response
    # OpenAI format: {"choices": [{"message": {"content": "..."}}]}
    local content
    content=$(echo "$response" | jq -r '.choices[0].message.content // empty')

    if [[ -z "$content" ]]; then
        echo "Error: No content in response" >&2
        echo "$response" | jq '.' >&2
        return 1
    fi

    # Write to output file
    echo "$content" > "${params[output_file]}"

    # Display with less
    less "${params[output_file]}"

    return 0
}

# Execute OpenAI-compatible API request in streaming mode
# Streams response in real-time using Server-Sent Events (SSE)
#
# Args:
#   All arguments are key=value pairs (same as openai_execute_single):
#   model, max_tokens, temperature
#   system_blocks_file, user_blocks_file, output_file
#
# Returns:
#   0 - Success (response written to output_file)
#   1 - API error or network failure
openai_execute_stream() {
    # Parse key=value arguments into associative array
    local -A params
    while [[ $# -gt 0 ]]; do
        IFS='=' read -r key value <<< "$1"
        params["$key"]="$value"
        shift
    done

    # Validate configuration
    if ! openai_validate; then
        return 1
    fi

    # Convert messages to OpenAI format
    local messages
    messages=$(convert_to_openai_messages "${params[system_blocks_file]}" "${params[user_blocks_file]}")

    # Build JSON payload with streaming enabled
    local json_payload
    json_payload=$(jq -n \
        --arg model "${params[model]}" \
        --argjson max_tokens "${params[max_tokens]}" \
        --argjson temperature "${params[temperature]}" \
        --argjson messages "$messages" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            temperature: $temperature,
            messages: $messages,
            stream: true
        }')

    # Execute streaming request
    echo "Sending OpenAI-compatible API request (streaming)..."
    echo "---"
    echo ""

    # Initialize output file
    > "${params[output_file]}"

    # Use error flag file to communicate from pipeline subshell
    local error_flag
    error_flag=$(mktemp)
    : > "$error_flag"

    # Stream response and parse SSE events
    # OpenAI SSE format:
    #   data: {"id":"...","choices":[{"delta":{"content":"..."}}]}
    #   data: [DONE]
    echo "$json_payload" | curl -Ns "${OPENAI_BASE_URL}/chat/completions" \
        -H "Authorization: Bearer ${OPENAI_API_KEY:-lm-studio}" \
        -H "Content-Type: application/json" \
        -d @- | while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Parse SSE format (lines start with "data: ")
        if [[ "$line" == data:* ]]; then
            json_data="${line#data: }"

            # Skip [DONE] marker
            if [[ "$json_data" == "[DONE]" ]]; then
                continue
            fi

            # Check for error in streaming response
            if echo "$json_data" | jq -e '.error' > /dev/null 2>&1; then
                echo "" >&2
                echo "API Error:" >&2
                echo "$json_data" | jq '.error' >&2
                echo "error" > "$error_flag"
                exit 1
            fi

            # Extract delta content
            # OpenAI: {"choices": [{"delta": {"content": "..."}}]}
            local delta_content
            delta_content=$(echo "$json_data" | jq -r '.choices[0].delta.content // empty')

            if [[ -n "$delta_content" ]]; then
                printf '%s' "$delta_content"
                printf '%s' "$delta_content" >> "${params[output_file]}"
            fi

            # Check for finish reason
            local finish_reason
            finish_reason=$(echo "$json_data" | jq -r '.choices[0].finish_reason // empty')

            if [[ "$finish_reason" == "stop" ]]; then
                printf '\n'
            fi
        fi
    done

    # Check if error occurred in pipeline
    if [[ -s "$error_flag" ]]; then
        rm -f "$error_flag"
        return 1
    fi
    rm -f "$error_flag"

    echo ""
    echo "---"

    return 0
}

# Resolve model name for OpenAI provider based on profile
# Uses OPENAI_MODEL_* variables similar to Anthropic profile system
# Args:
#   $1 - Profile name (fast, balanced, deep) or empty for default
# Returns:
#   Model name to stdout
openai_resolve_model() {
    local profile="${1:-balanced}"

    # Explicit model override takes precedence
    if [[ -n "$OPENAI_MODEL" ]]; then
        echo "$OPENAI_MODEL"
        return 0
    fi

    # Resolve based on profile
    case "$profile" in
        fast)
            if [[ -n "$OPENAI_MODEL_FAST" ]]; then
                echo "$OPENAI_MODEL_FAST"
            else
                echo "Error: OPENAI_MODEL_FAST is not configured" >&2
                return 1
            fi
            ;;
        balanced)
            if [[ -n "$OPENAI_MODEL_BALANCED" ]]; then
                echo "$OPENAI_MODEL_BALANCED"
            else
                echo "Error: OPENAI_MODEL_BALANCED is not configured" >&2
                return 1
            fi
            ;;
        deep)
            if [[ -n "$OPENAI_MODEL_DEEP" ]]; then
                echo "$OPENAI_MODEL_DEEP"
            else
                echo "Error: OPENAI_MODEL_DEEP is not configured" >&2
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown profile: $profile" >&2
            return 1
            ;;
    esac

    return 0
}

# Check if a feature is supported by OpenAI provider
# Returns 0 if supported, 1 if not (and prints warning)
# Args:
#   $1 - Feature name (thinking, effort, citations, batch, pdf)
openai_check_feature() {
    local feature="$1"

    case "$feature" in
        thinking)
            echo "Warning: Extended thinking is not supported by OpenAI provider - ignoring" >&2
            return 1
            ;;
        effort)
            echo "Warning: Effort parameter is not supported by OpenAI provider - ignoring" >&2
            return 1
            ;;
        citations)
            echo "Warning: Citations are not supported by OpenAI provider - disabling" >&2
            return 1
            ;;
        batch)
            echo "Error: Batch API is not supported by OpenAI provider" >&2
            return 1
            ;;
        pdf)
            # PDFs need to be converted to images
            return 1
            ;;
        cache)
            # Prompt caching silently ignored (no warning needed)
            return 1
            ;;
        *)
            # Unknown feature - assume supported
            return 0
            ;;
    esac
}
