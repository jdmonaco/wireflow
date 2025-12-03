# =============================================================================
# Run Mode Execution Functions
# =============================================================================
# Execute workflows with full context aggregation and dependency resolution.
# =============================================================================

# Execute workflow in run mode
# Arguments:
#   $@ - Execution options (model, temperature, input files, etc.)
execute_run_mode() {
    # Execution flags are globals set in wireflow.sh
    # STREAM_MODE defaults to "false" for run mode (already set in wireflow.sh)
    # DRY_RUN, COUNT_TOKENS, AUTO_DEPS also set in wireflow.sh

    # Initialize CLI override arrays (paths can be files or directories)
    local -a cli_input_paths=()
    local -a cli_context_paths=()
    
    # Parse execution options
    while [[ $# -gt 0 ]]; do
        # Try shared parser first (handles model, thinking, API options)
        parse_common_option "$1" "${@:2}"
        if [[ $PARSE_CONSUMED -gt 0 ]]; then
            shift $PARSE_CONSUMED
            continue
        fi

        # Handle run-mode specific options
        case "$1" in
            --stream|-s)
                STREAM_MODE="true"
                shift
                ;;
            --dry-run|-n)
                DRY_RUN="true"
                shift
                ;;
            --count-tokens)
                COUNT_TOKENS="true"
                shift
                ;;
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
            --depends-on|-dp)
                shift
                [[ $# -eq 0 || "$1" =~ ^- ]] && { echo "Error: --depends-on requires at least one argument" >&2; return 1; }
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    DEPENDS_ON+=("$1")
                    shift
                done
                WORKFLOW_SOURCE_MAP[DEPENDS_ON]="cli"
                ;;
            --export|-ex)
                shift
                [[ $# -eq 0 ]] && { echo "Error: --export requires argument" >&2; return 1; }
                EXPORT_PATH="$1"
                WORKFLOW_SOURCE_MAP[EXPORT_PATH]="cli"
                shift
                ;;
            --no-auto-deps)
                AUTO_DEPS="false"
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                show_quick_help_run
                return 1
                ;;
        esac
    done

    # =============================================================================
    # Automatic Dependency Execution
    # =============================================================================

    # Check if we should auto-execute stale dependencies
    if [[ "$AUTO_DEPS" == "true" && ${#DEPENDS_ON[@]} -gt 0 ]]; then
        echo "Resolving dependencies..."

        # Get execution order (topological sort)
        local -a exec_order
        if ! mapfile -t exec_order < <(resolve_dependency_order "$WORKFLOW_NAME"); then
            return 1
        fi

        # Execute stale dependencies (all except target, which is last)
        local i dep
        for ((i=0; i<${#exec_order[@]}-1; i++)); do
            dep="${exec_order[i]}"

            if is_execution_stale "$dep"; then
                echo "  Dependency '$dep' is stale, executing..."

                # Execute in subprocess for config isolation
                if ! execute_dependency "$dep"; then
                    echo "Error: Failed to execute dependency '$dep'" >&2
                    return 1
                fi
                echo "  Dependency '$dep' completed"
            else
                echo "  Dependency '$dep' is fresh, skipping"
            fi
        done
        echo ""
    fi

    # =============================================================================
    # Setup Paths
    # =============================================================================
    
    # Task prompt file
    local task_prompt_file="$WORKFLOW_DIR/task.txt"
    
    # Validate task file exists
    if [[ ! -f "$task_prompt_file" ]]; then
        echo "Error: Task file not found: $task_prompt_file" >&2
        echo "Workflow may be incomplete. Re-create with: $SCRIPT_NAME new $WORKFLOW_NAME" >&2
        return 1
    fi
    
    # Global file paths for API and citations
    DOCUMENT_MAP_FILE="$WORKFLOW_DIR/document-map.json"
    
    # Output files
    local output_file="$WORKFLOW_DIR/output.${OUTPUT_FORMAT}"
    local output_link="$OUTPUT_DIR/${WORKFLOW_NAME}.${OUTPUT_FORMAT}"
    
    # Set CLI-provided paths for aggregation (must match execute.sh variable names)
    # These can be files or directories; execute.sh handles expansion
    CLI_INPUT_PATHS=("${cli_input_paths[@]}")
    CLI_CONTEXT_PATHS=("${cli_context_paths[@]}")

    # Reset global content block arrays for this run
    SYSTEM_BLOCKS=()
    CONTEXT_BLOCKS=()
    DEPENDENCY_BLOCKS=()
    INPUT_BLOCKS=()
    IMAGE_BLOCKS=()
    DOCUMENT_INDEX_MAP=()

    # =============================================================================
    # Build System Prompt
    # =============================================================================
    
    if ! build_system_prompt; then
        echo "Error: Failed to build system prompt" >&2
        return 1
    fi
    
    # =============================================================================
    # Context Aggregation
    # =============================================================================
    
    aggregate_context "run" "$PROJECT_ROOT" "$WORKFLOW_DIR"
    
    # =============================================================================
    # Build Final Prompts
    # =============================================================================
    
    build_prompts "$PROJECT_ROOT" "$task_prompt_file"

    # =============================================================================
    # Token Estimation (if requested)
    # =============================================================================

    if [[ "$COUNT_TOKENS" == "true" ]]; then
        estimate_tokens
        return 0
    fi
    
    # =============================================================================
    # Execute API Request
    # =============================================================================

    # Warn if workflow has BATCH_MODE=true configured
    if [[ "$BATCH_MODE" == "true" ]]; then
        echo "Warning: This workflow has BATCH_MODE=true configured."
        echo "Consider using: $SCRIPT_NAME batch $WORKFLOW_NAME"
        echo ""
    fi

    # Execute API request (dry-run handled internally)
    execute_api_request "run" "$output_file" "" "$WORKFLOW_DIR"
    local api_result=$?

    if [[ $api_result -ne 0 ]]; then
        echo "Error: API request failed" >&2
        return $api_result
    fi
    
    # =============================================================================
    # Post-Processing
    # =============================================================================
    
    # Convert JSON files to XML (optional, if yq available)
    convert_json_to_xml "$WORKFLOW_DIR"
    
    echo "Response saved to: $(display_absolute_path "$output_file")"
    
    # Format-specific post-processing
    if [[ -f "$output_file" ]]; then
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
    fi
    
    # Create/update hardlink in output directory
    mkdir -p "$OUTPUT_DIR"
    if [[ -f "$output_link" ]]; then
        rm "$output_link"
    fi
    ln "$output_file" "$output_link"
    echo "Hardlink created: $(display_absolute_path "$output_link")"
    
    # Copy output file to EXPORT_PATH if specified
    if [[ -n "$EXPORT_PATH" ]]; then
        # Resolve path: expand ~/, resolve relative paths to project root
        local resolved_path="${EXPORT_PATH/#\~/$HOME}"
        if [[ "$resolved_path" != /* ]]; then
            resolved_path="$PROJECT_ROOT/$resolved_path"
        fi
        
        # Create parent directories
        local export_dir=$(dirname "$resolved_path")
        if mkdir -p "$export_dir" 2>/dev/null; then
            # Copy with preserved timestamps
            if cp -p "$output_file" "$resolved_path" 2>/dev/null; then
                echo "Response exported to: $(display_absolute_path "$resolved_path")"
            else
                echo "Warning: Export failed to $resolved_path" >&2
            fi
        else
            echo "Warning: Failed to create export directory $export_dir" >&2
        fi
    fi
    
    echo
    echo "Workflow '$WORKFLOW_NAME' completed successfully!"
    
    return 0
}
