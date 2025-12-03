# =============================================================================
# Task Mode Execution Functions
# =============================================================================
# Lightweight one-off task execution without creating workflow directories.
# Supports named tasks from files or inline task specifications.
# =============================================================================

# Execute task in standalone mode
# Arguments:
#   $1 - Task content (text)
#   $2 - Task source (name or "inline")
#   $@ - Execution options (model, temperature, input files, etc.)
execute_task_mode() {
    local task_content="$1"
    local task_source="$2"
    shift 2
    
    # Validate task content
    if [[ -z "$task_content" ]]; then
        echo "Error: Empty task content" >&2
        return 1
    fi
    
    # Task mode defaults to streaming (run mode defaults to non-streaming)
    STREAM_MODE="true"

    # Initialize task-specific variables (paths can be files or directories)
    local -a cli_input_paths=()
    local -a cli_context_paths=()
    local output_file_path=""
    
    # Parse execution options
    while [[ $# -gt 0 ]]; do
        # Try shared parser first (handles model, thinking, API options)
        parse_common_option "$1" "${@:2}"
        if [[ $PARSE_CONSUMED -gt 0 ]]; then
            shift $PARSE_CONSUMED
            continue
        fi

        # Handle task-mode specific options
        case "$1" in
            --input|-in)
                shift
                [[ $# -eq 0 || "$1" =~ ^- ]] && { echo "Error: --input requires at least one argument" >&2; return 1; }
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    cli_input_paths+=("$1")
                    shift
                done
                ;;
            --context|-cx)
                shift
                [[ $# -eq 0 || "$1" =~ ^- ]] && { echo "Error: --context requires at least one argument" >&2; return 1; }
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    cli_context_paths+=("$1")
                    shift
                done
                ;;
            --)
                shift
                # All remaining arguments are input file/directory paths
                while [[ $# -gt 0 ]]; do
                    cli_input_paths+=("$1")
                    shift
                done
                ;;
            --export|-ex)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --export requires argument" >&2; return 1; }
                output_file_path="$1"
                shift
                ;;
            --stream|-s)
                STREAM_MODE="true"
                shift
                ;;
            --no-stream|-b)
                STREAM_MODE="false"
                shift
                ;;
            --count-tokens)
                COUNT_TOKENS="true"
                shift
                ;;
            --dry-run|-n)
                DRY_RUN="true"
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                show_quick_help_task
                return 1
                ;;
        esac
    done

    # =============================================================================
    # Model Validation
    # =============================================================================

    # Resolve and validate model exists before expensive operations
    local resolved_model
    local provider="${PROVIDER:-anthropic}"

    if [[ "$provider" == "openai" ]]; then
        resolved_model=$(openai_resolve_model) || return 1
    else
        resolved_model=$(resolve_model)
    fi

    echo "Validating model availability..."
    if ! validate_model_availability "$resolved_model" "$provider"; then
        echo "" >&2
        echo "Hint: Use 'wfw models' to see available models" >&2
        return 1
    fi

    # =============================================================================
    # Terminal Output Warning
    # =============================================================================

    # Warn if output will stream to terminal without being saved
    if [[ -t 1 ]] && [[ -z "$output_file_path" ]] && \
       [[ "$DRY_RUN" != "true" ]] && [[ "$COUNT_TOKENS" != "true" ]]; then
        echo "Warning: Output will stream to terminal and not be saved."
        echo "  Use --export/-ex <path> to save output to a file."
        echo
        prompt_to_continue_or_exit
    fi

    # =============================================================================
    # Optional Project Discovery and Configuration
    # =============================================================================
    
    # Try to find project root (non-fatal)
    local project_root
    project_root=$(find_project_root 2>/dev/null) || true
    
    # Load project and ancestor configs if in a project
    if [[ -n "$project_root" ]]; then
        echo "Using project context from: $(display_absolute_path "$project_root")"

        # Load ancestor configs
        load_ancestor_configs

        # Load project config
        load_project_config "$project_root/.workflow/config"

        # Set project-level cache directory for file conversions
        CACHE_DIR="$project_root/.workflow/cache"
    else
        echo "Running in standalone mode (no project context)"
        # No project = no persistent cache for file conversions
        CACHE_DIR=""
    fi

    # =============================================================================
    # Context Aggregation Setup
    # =============================================================================

    # Set CLI-provided paths for aggregation (must match execute.sh variable names)
    # These can be files or directories; execute.sh handles expansion
    CLI_INPUT_PATHS=("${cli_input_paths[@]}")
    CLI_CONTEXT_PATHS=("${cli_context_paths[@]}")
    
    # Create temporary cache directory for image processing
    local task_cache_dir
    task_cache_dir=$(mktemp -d)
    trap "rm -rf $task_cache_dir" EXIT

    # Document map file for citations (temp file for task mode)
    DOCUMENT_MAP_FILE="$task_cache_dir/document-map.json"

    # Reset global content block arrays for this task
    SYSTEM_BLOCKS=()
    CONTEXT_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    INPUT_BLOCKS=()
    IMAGE_BLOCKS=()
    DOCUMENT_INDEX_MAP=()

    # =============================================================================
    # Build System Prompt
    # =============================================================================

    # Build system prompt from current configuration
    if ! build_system_prompt; then
        echo "Error: Failed to build system prompt" >&2
        return 1
    fi

    # Aggregate context (no workflow dependencies in task mode)
    aggregate_context "task" "$project_root" "$task_cache_dir"
    
    # =============================================================================
    # Build Final Prompts
    # =============================================================================
    
    build_prompts "$project_root" "$task_content"
    
    # =============================================================================
    # Token Estimation (if requested)
    # =============================================================================
    
    if [[ "$COUNT_TOKENS" == "true" ]]; then
        estimate_tokens
        return 0
    fi
    
    # =============================================================================
    # Output File Setup
    # =============================================================================
    
    local output_file
    if [[ -n "$output_file_path" ]]; then
        # User specified explicit output file
        output_file="$output_file_path"
        
        # Backup if file exists
        if [[ -f "$output_file" ]]; then
            echo "Backing up previous output file..."
            local output_bak="${output_file%.*}-$(date +"%Y%m%d%H%M%S").${output_file##*.}"
            mv -v "$output_file" "$output_bak"
            echo
        fi
    else
        # No output file - use temp file for API function
        output_file=$(mktemp)
        trap "rm -f $output_file" EXIT
    fi
    
    # =============================================================================
    # Execute API Request
    # =============================================================================

    # Execute API request (dry-run handled internally)
    execute_api_request "task" "$output_file" "$output_file_path" "$task_cache_dir"
    local api_result=$?

    if [[ $api_result -ne 0 ]]; then
        echo "Error: API request failed" >&2
        return $api_result
    fi
    
    # =============================================================================
    # Post-Processing
    # =============================================================================
    
    # Handle citations output
    if [[ "$ENABLE_CITATIONS" == "true" && -n "$CITATIONS_FILE_PATH" && -f "$CITATIONS_FILE_PATH" && -s "$CITATIONS_FILE_PATH" ]]; then
        if [[ -z "$output_file_path" ]]; then
            # Stdout mode: append citations to stdout after separator
            echo
            echo "---"
            echo
            cat "$CITATIONS_FILE_PATH"
        else
            # Explicit output file: move citations alongside with proper naming
            local output_dir=$(dirname "$output_file")
            local output_base=$(basename "$output_file" ".${OUTPUT_FORMAT}")
            local citations_output="${output_dir}/${output_base}-citations.md"
            mv "$CITATIONS_FILE_PATH" "$citations_output"
            echo "Citations saved to: $(display_absolute_path "$citations_output")"
        fi
    fi
    
    # Only post-process if output file was explicitly specified
    if [[ -n "$output_file_path" && -f "$output_file" ]]; then
        echo
        echo "Response saved to: $(display_absolute_path "$output_file")"
        
        # Format-specific post-processing
        case "$OUTPUT_FORMAT" in
            md|markdown)
                if command -v mdformat &>/dev/null; then
                    echo "Formatting output with mdformat..."
                    mdformat --no-validate "$output_file" 2>/dev/null
                fi
                ;;
            json)
                if command -v jq &>/dev/null; then
                    echo "Formatting output with jq..."
                    jq . "$output_file" > "${output_file}.tmp" && mv "${output_file}.tmp" "$output_file"
                fi
                ;;
            # txt, html, etc. - no formatting needed
        esac
        
        echo
        echo "Task completed successfully!"
    fi
    
    return 0
}
