# =============================================================================
# Models Subcommand Functions
# =============================================================================
# Display provider settings and available models from API endpoints.
# Supports Anthropic Claude API and OpenAI-compatible providers.
# Special handling for LM Studio servers (port :1234) using richer v0 API.
# =============================================================================

# Check if URL is LM Studio (port :1234)
is_lmstudio_server() {
    local url="$1"
    [[ "$url" =~ :1234(/|$) ]]
}

# Query Anthropic /v1/models endpoint
fetch_anthropic_models() {
    curl -s --max-time 5 "https://api.anthropic.com/v1/models?limit=100" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01"
}

# Query OpenAI-compatible /v1/models endpoint
fetch_openai_models() {
    local base_url="${OPENAI_BASE_URL:-}"
    [[ -z "$base_url" ]] && return 1
    curl -s --max-time 5 "$base_url/models" \
        -H "Authorization: Bearer ${OPENAI_API_KEY:-fake-api-key}"
}

# Query LM Studio /api/v0/models endpoint (richer info)
fetch_lmstudio_models() {
    local base_url="${OPENAI_BASE_URL:-}"
    [[ -z "$base_url" ]] && return 1
    # Strip /v1 suffix to get base, then add /api/v0/models
    local lms_base="${base_url%/v1}"
    curl -s --max-time 5 "$lms_base/api/v0/models"
}

# Check server availability with timeout
check_server_status() {
    local url="$1"
    local timeout="${2:-2}"
    curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" -I "$url" 2>/dev/null
}

# Get single model info from Anthropic
fetch_anthropic_model() {
    local model_id="$1"
    curl -s --max-time 5 "https://api.anthropic.com/v1/models/$model_id" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01"
}

# Get single model info from OpenAI-compatible
fetch_openai_model() {
    local model_id="$1"
    local base_url="${OPENAI_BASE_URL:-}"
    curl -s --max-time 5 "$base_url/models/$model_id" \
        -H "Authorization: Bearer ${OPENAI_API_KEY:-fake-api-key}"
}

# Get single model info from LM Studio v0 API
fetch_lmstudio_model() {
    local model_id="$1"
    local base_url="${OPENAI_BASE_URL:-}"
    local lms_base="${base_url%/v1}"
    curl -s --max-time 5 "$lms_base/api/v0/models/$model_id"
}

# =============================================================================
# Model Validation
# =============================================================================

# Validate that the resolved model exists via API endpoint
# Arguments:
#   $1 - Model ID to validate
#   $2 - Provider (anthropic or openai)
# Returns: 0 if model exists, 1 if not found or error
# Note: Skipped when WIREFLOW_TEST_MODE=true
validate_model_availability() {
    local model_id="$1"
    local provider="${2:-${PROVIDER:-anthropic}}"

    # Skip validation in test mode
    if [[ "${WIREFLOW_TEST_MODE:-}" == "true" ]]; then
        return 0
    fi

    if [[ -z "$model_id" ]]; then
        echo "Error: No model ID specified" >&2
        return 1
    fi

    local result
    local error_msg

    case "$provider" in
        anthropic)
            result=$(fetch_anthropic_model "$model_id" 2>/dev/null)
            if [[ -z "$result" ]]; then
                echo "Error: Failed to connect to Anthropic API" >&2
                return 1
            fi
            # Check for error response
            if echo "$result" | jq -e '.error' &>/dev/null; then
                error_msg=$(echo "$result" | jq -r '.error.message // .error' 2>/dev/null)
                echo "Error: Model '$model_id' not found on Anthropic API" >&2
                echo "  API response: $error_msg" >&2
                return 1
            fi
            # Verify we got a valid model response
            if ! echo "$result" | jq -e '.id' &>/dev/null; then
                echo "Error: Invalid response from Anthropic API for model '$model_id'" >&2
                return 1
            fi
            ;;
        openai)
            if [[ -z "$OPENAI_BASE_URL" ]]; then
                echo "Error: OPENAI_BASE_URL not configured" >&2
                return 1
            fi
            # Check server availability first
            local status_code
            status_code=$(check_server_status "$OPENAI_BASE_URL/models" 3)
            if [[ "$status_code" != "200" ]]; then
                echo "Error: OpenAI-compatible server not available at $OPENAI_BASE_URL (HTTP $status_code)" >&2
                return 1
            fi
            # Fetch model info (use standard OpenAI endpoint for all servers)
            result=$(fetch_openai_model "$model_id" 2>/dev/null)
            if [[ -z "$result" ]]; then
                echo "Error: Failed to query model from OpenAI-compatible server" >&2
                return 1
            fi
            # Check for error response
            if echo "$result" | jq -e '.error' &>/dev/null; then
                error_msg=$(echo "$result" | jq -r '.error // "Model not found"' 2>/dev/null)
                echo "Error: Model '$model_id' not found on OpenAI-compatible server" >&2
                echo "  Server response: $error_msg" >&2
                return 1
            fi
            # Verify we got a valid model response
            if ! echo "$result" | jq -e '.id' &>/dev/null; then
                echo "Error: Invalid response from server for model '$model_id'" >&2
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown provider '$provider'" >&2
            return 1
            ;;
    esac

    return 0
}

# Main entry point for models subcommand
cmd_models() {
    local subcmd="${1:-}"

    case "$subcmd" in
        show)
            shift
            cmd_models_show "$@"
            ;;
        ""|list)
            cmd_models_list
            ;;
        -h|--help)
            show_help_models
            ;;
        *)
            echo "Error: Unknown models subcommand: $subcmd" >&2
            show_quick_help_models
            return 1
            ;;
    esac
}

# Display all provider settings and available models
cmd_models_list() {
    # Load configuration cascade
    load_global_config

    # Optionally load project config if in a project
    local project_root
    project_root=$(find_project_root 2>/dev/null) || true
    if [[ -n "$project_root" ]]; then
        load_ancestor_configs
        load_project_config "$project_root/.workflow/config"
    fi

    # Determine active provider
    local active_provider="${PROVIDER:-anthropic}"

    # Anthropic section
    if [[ "$active_provider" == "anthropic" ]]; then
        echo "Anthropic (Claude API)  [active]"
    else
        echo "Anthropic (Claude API)"
    fi
    display_anthropic_section
    echo

    # Only show OpenAI section if configured
    if [[ -n "$OPENAI_BASE_URL" ]]; then
        if [[ "$active_provider" == "openai" ]]; then
            echo "OpenAI-Compatible Provider  [active]"
        else
            echo "OpenAI-Compatible Provider"
        fi
        display_openai_section
    fi
    echo
}

# Display Anthropic section with profile and available models
display_anthropic_section() {
    # Profile settings (widths: 11 + 38 = 49 chars to bracket, matching model lines)
    printf "  Profile: %-38s [%s]\n" "$PROFILE" "${CONFIG_SOURCE_MAP[PROFILE]:-builtin}"
    printf "    fast:     %-35s [%s]\n" "$MODEL_FAST" "${CONFIG_SOURCE_MAP[MODEL_FAST]:-builtin}"
    printf "    balanced: %-35s [%s]\n" "$MODEL_BALANCED" "${CONFIG_SOURCE_MAP[MODEL_BALANCED]:-builtin}"
    printf "    deep:     %-35s [%s]\n" "$MODEL_DEEP" "${CONFIG_SOURCE_MAP[MODEL_DEEP]:-builtin}"
    echo

    # Fetch and display available models
    echo "  Available Models:"
    local models_json
    if models_json=$(fetch_anthropic_models 2>/dev/null); then
        if echo "$models_json" | jq -e '.data' &>/dev/null; then
            echo "$models_json" | jq -r '
                .data[] |
                "    " +
                (.id | .[0:30] | . + " " * (30 - length)) + "  " +
                (.display_name | .[0:25] | . + " " * (25 - length)) + "  " +
                (.created_at | .[0:10])
            ' 2>/dev/null
        else
            echo "    (failed to parse response)"
        fi
    else
        echo "    (failed to fetch - check ANTHROPIC_API_KEY)"
    fi
}

# Display OpenAI-compatible section with status and models
display_openai_section() {
    printf "  Base URL: %-40s [%s]\n" "$OPENAI_BASE_URL" "${USER_ENV_SOURCE_MAP[OPENAI_BASE_URL]:-builtin}"

    # Check server status
    local status_code
    status_code=$(check_server_status "$OPENAI_BASE_URL/models")

    if [[ "$status_code" == "200" ]]; then
        if is_lmstudio_server "$OPENAI_BASE_URL"; then
            echo "  Status: Online (LM Studio)"
        else
            echo "  Status: Online"
        fi
    else
        echo "  Status: Offline (HTTP $status_code)"
        return 0
    fi

    # Model profile settings
    printf "    fast:     %-35s [%s]\n" "${OPENAI_MODEL_FAST:-(not configured)}" "${CONFIG_SOURCE_MAP[OPENAI_MODEL_FAST]:-builtin}"
    printf "    balanced: %-35s [%s]\n" "${OPENAI_MODEL_BALANCED:-(not configured)}" "${CONFIG_SOURCE_MAP[OPENAI_MODEL_BALANCED]:-builtin}"
    printf "    deep:     %-35s [%s]\n" "${OPENAI_MODEL_DEEP:-(not configured)}" "${CONFIG_SOURCE_MAP[OPENAI_MODEL_DEEP]:-builtin}"
    echo

    # Fetch and display available models
    echo "  Available Models:"
    if is_lmstudio_server "$OPENAI_BASE_URL"; then
        display_lmstudio_models
    else
        display_openai_models
    fi
}

# Display models from standard OpenAI /v1/models
display_openai_models() {
    local models_json
    if models_json=$(fetch_openai_models 2>/dev/null); then
        if echo "$models_json" | jq -e '.data' &>/dev/null; then
            echo "$models_json" | jq -r '.data | sort_by(.id) | .[].id | "    \(.)"' 2>/dev/null
        else
            echo "    (failed to parse response)"
        fi
    else
        echo "    (failed to fetch models)"
    fi
}

# Display models from LM Studio /api/v0/models with rich info
display_lmstudio_models() {
    local models_json
    if models_json=$(fetch_lmstudio_models 2>/dev/null); then
        if echo "$models_json" | jq -e '.data' &>/dev/null; then
            # Format: * id (loaded indicator)  type  quant  format  context  [capabilities]
            echo "$models_json" | jq -r '
                .data | sort_by(.id) | .[] |
                (if .state == "loaded" then "  * " else "    " end) +
                (.id | .[0:30] | . + " " * (30 - length)) + "  " +
                ((.type // "?") | .[0:4] | . + " " * (4 - length)) + "  " +
                ((.quantization // "?") | .[0:6] | . + " " * (6 - length)) + "  " +
                ((.compatibility_type // "?") | .[0:4] | . + " " * (4 - length)) + "  " +
                (if .state == "loaded" then "\(.loaded_context_length // "?")/\(.max_context_length // "?")" else "\(.max_context_length // "?")" end | tostring | .[0:12] | . + " " * (12 - length)) +
                (if .capabilities and (.capabilities | length) > 0 then "  [\(.capabilities | join(","))]" else "" end)
            ' 2>/dev/null
        else
            echo "    (failed to parse response)"
        fi
    else
        echo "    (failed to fetch models)"
    fi
}

# Show detailed info for a specific model
cmd_models_show() {
    local model_id="$1"

    if [[ -z "$model_id" ]]; then
        echo "Error: Model ID required" >&2
        echo "Usage: wfw models show <model_id>" >&2
        return 1
    fi

    # Load config for API keys and URLs
    load_global_config

    # Try Anthropic first (if looks like a Claude model)
    if [[ "$model_id" =~ ^claude- ]]; then
        local result
        if result=$(fetch_anthropic_model "$model_id" 2>/dev/null); then
            if echo "$result" | jq -e '.id' &>/dev/null; then
                echo "$result" | jq .
                return 0
            fi
        fi
    fi

    # Try OpenAI-compatible if configured
    if [[ -n "$OPENAI_BASE_URL" ]]; then
        local status_code
        status_code=$(check_server_status "$OPENAI_BASE_URL/models")

        if [[ "$status_code" == "200" ]]; then
            local result
            if is_lmstudio_server "$OPENAI_BASE_URL"; then
                result=$(fetch_lmstudio_model "$model_id" 2>/dev/null)
            else
                result=$(fetch_openai_model "$model_id" 2>/dev/null)
            fi

            if [[ -n "$result" ]] && echo "$result" | jq -e '.id' &>/dev/null; then
                echo "$result" | jq .
                return 0
            fi
        fi
    fi

    # If not Claude model, try Anthropic anyway as fallback
    if [[ ! "$model_id" =~ ^claude- ]]; then
        local result
        if result=$(fetch_anthropic_model "$model_id" 2>/dev/null); then
            if echo "$result" | jq -e '.id' &>/dev/null; then
                echo "$result" | jq .
                return 0
            fi
        fi
    fi

    echo "Error: Model '$model_id' not found" >&2
    return 1
}
