#!/usr/bin/env bash

# =============================================================================
# Workflow Core Functions
# =============================================================================
# Core workflow subcommand implementations for the workflow CLI tool.
# This file is sourced by workflow.sh.
# Dependencies: lib/utils.sh (must be sourced first)
# =============================================================================

# Source utility functions if not already loaded
SCRIPT_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
if ! declare -f sanitize > /dev/null; then
    source "$SCRIPT_LIB_DIR/utils.sh"
fi

# =============================================================================
# Help Text
# =============================================================================
show_help() {
    cat <<EOF
Usage: $(basename ${0}) SUBCOMMAND [OPTIONS]

SUBCOMMANDS:
    init [dir]              Initialize workflow project (default: current dir)
    new NAME                Create new workflow in current project
    edit [NAME]             Edit workflow or project (if NAME omitted)
    list                    List all workflows in current project
    run NAME [OPTIONS]      Execute workflow

RUN OPTIONS:
    --stream                Use streaming API mode (default: single-batch)
    --dry-run               Estimate tokens only, don't make API call
    --context-pattern GLOB  Glob pattern for context files
    --context-file FILE     Add specific file (repeatable)
    --depends-on WORKFLOW   Include output from another workflow
    --model MODEL           Override model from config
    --temperature TEMP      Override temperature
    --max-tokens NUM        Override max tokens
    --system-prompts LIST   Comma-separated prompt names (overrides config)
    --output-format EXT     Output format/extension (default: md)

OTHER:
    --help, -h, help        Show this help message

EXAMPLES:
    # Initialize project
    $(basename ${0}) init .

    # Create new workflow
    $(basename ${0}) new 01-outline-draft

    # Edit project configuration
    $(basename ${0}) edit

    # Edit existing workflow
    $(basename ${0}) edit 01-outline-draft

    # Execute workflow (uses .workflow/01-outline-draft/config)
    $(basename ${0}) run 01-outline-draft

    # Execute with streaming
    $(basename ${0}) run 01-outline-draft --stream

    # Execute with overrides
    $(basename ${0}) run 02-intro --depends-on 01-outline-draft --max-tokens 8192

EOF
}

# =============================================================================
# Init Subcommand - Initialize Project
# =============================================================================
init_project() {
    local target_dir="${1:-.}"

    # Check if already initialized
    if [[ -d "$target_dir/.workflow" ]]; then
        echo "Error: Project already initialized at $target_dir"
        echo "Found existing .workflow/ directory"
        exit 1
    fi

    # Initialize config values with defaults
    INHERITED_MODEL="$DEFAULT_MODEL"
    INHERITED_TEMPERATURE="$DEFAULT_TEMPERATURE"
    INHERITED_MAX_TOKENS="$DEFAULT_MAX_TOKENS"
    INHERITED_OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
    INHERITED_SYSTEM_PROMPTS="Root"

    # Check for parent project (handles both nesting detection and inheritance)
    PARENT_ROOT=$(cd "$target_dir" && find_project_root 2>/dev/null) || true
    if [[ -n "$PARENT_ROOT" ]]; then
        echo "Initializing nested project inside existing project at:"
        echo "  $PARENT_ROOT"
        echo ""
        echo "This will:"
        echo "  - Create a separate workflow namespace"
        echo "  - Inherit configuration defaults from parent"
        read -p "Continue? [y/N] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

        echo ""
        echo "Inheriting configuration from parent..."

        # Extract config from parent
        while IFS='=' read -r key value; do
            case "$key" in
                MODEL)
                    [[ -n "$value" ]] && INHERITED_MODEL="$value"
                    ;;
                TEMPERATURE)
                    [[ -n "$value" ]] && INHERITED_TEMPERATURE="$value"
                    ;;
                MAX_TOKENS)
                    [[ -n "$value" ]] && INHERITED_MAX_TOKENS="$value"
                    ;;
                OUTPUT_FORMAT)
                    [[ -n "$value" ]] && INHERITED_OUTPUT_FORMAT="$value"
                    ;;
                SYSTEM_PROMPTS)
                    [[ -n "$value" ]] && INHERITED_SYSTEM_PROMPTS="$value"
                    ;;
            esac
        done < <(extract_parent_config "$PARENT_ROOT/.workflow/config")

        # Display inherited values
        echo "  MODEL: $INHERITED_MODEL"
        echo "  TEMPERATURE: $INHERITED_TEMPERATURE"
        echo "  MAX_TOKENS: $INHERITED_MAX_TOKENS"
        echo "  SYSTEM_PROMPTS: $INHERITED_SYSTEM_PROMPTS"
        echo "  OUTPUT_FORMAT: $INHERITED_OUTPUT_FORMAT"
        echo ""
    fi

    # Create .workflow structure
    mkdir -p "$target_dir/.workflow/prompts"
    mkdir -p "$target_dir/.workflow/output"

    # Create default config with inherited values
    cat > "$target_dir/.workflow/config" <<CONFIG_EOF
# Project-level workflow configuration

# System prompts to concatenate (in order, space-separated)
# Names must map to \$WORKFLOW_PROMPT_PREFIX/System/{name}.txt
SYSTEM_PROMPTS=($INHERITED_SYSTEM_PROMPTS)

# API defaults
MODEL="$INHERITED_MODEL"
TEMPERATURE=$INHERITED_TEMPERATURE
MAX_TOKENS=$INHERITED_MAX_TOKENS

# Output format (extension without dot: md, txt, json, html, etc.)
OUTPUT_FORMAT="$INHERITED_OUTPUT_FORMAT"
CONFIG_EOF

    # Create empty project description file
    touch "$target_dir/.workflow/project.txt"

    echo "Initialized workflow project: $target_dir/.workflow/"
    echo "Created:"
    echo "  $target_dir/.workflow/config"
    echo "  $target_dir/.workflow/project.txt"
    echo "  $target_dir/.workflow/prompts/"
    echo "  $target_dir/.workflow/output/"
    echo ""
    echo "Opening project description and config in editor..."

    # Open both files in vim with vertical split
    ${EDITOR:-vim} -O "$target_dir/.workflow/project.txt" "$target_dir/.workflow/config"

    echo ""
    echo "Next steps:"
    echo "  1. cd $target_dir"
    echo "  2. workflow new WORKFLOW_NAME"
}

# =============================================================================
# New Subcommand - Create Workflow
# =============================================================================
new_workflow() {
    local workflow_name="$1"

    if [[ -z "$workflow_name" ]]; then
        echo "Error: Workflow name required"
        echo "Usage: workflow new NAME"
        exit 1
    fi

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    WORKFLOW_DIR="$PROJECT_ROOT/.workflow/$workflow_name"

    # Check if workflow already exists
    if [[ -d "$WORKFLOW_DIR" ]]; then
        echo "Error: Workflow '$workflow_name' already exists"
        exit 1
    fi

    # Create workflow directory
    mkdir -p "$WORKFLOW_DIR"

    # Create empty task file
    touch "$WORKFLOW_DIR/task.txt"

    # Create workflow config file
    cat > "$WORKFLOW_DIR/config" <<WORKFLOW_CONFIG_EOF
# Workflow-specific configuration
# These values override project defaults from .workflow/config

# Context aggregation methods (uncomment and configure as needed):
# Note: Paths in CONTEXT_PATTERN and CONTEXT_FILES are relative to project root

# Method 1: Glob pattern (single pattern, supports brace expansion)
# CONTEXT_PATTERN="References/*.md"
# CONTEXT_PATTERN="References/{Topic1,Topic2}/*.md"

# Method 2: Explicit file list
# CONTEXT_FILES=(
#     "References/doc1.md"
#     "References/doc2.md"
# )

# Method 3: Workflow dependencies
# DEPENDS_ON=(
#     "00-workshop-context"
#     "01-outline-draft"
# )

# API overrides (optional)
# MODEL="$DEFAULT_MODEL"
# TEMPERATURE=$DEFAULT_TEMPERATURE
# MAX_TOKENS=$DEFAULT_MAX_TOKENS
# SYSTEM_PROMPTS=(Root DataScience)

# Output format override (extension without dot: md, txt, json, html, etc.)
# OUTPUT_FORMAT="txt"
# OUTPUT_FORMAT="json"
WORKFLOW_CONFIG_EOF

    echo "Created workflow: $workflow_name"
    echo "  $WORKFLOW_DIR/task.txt"
    echo "  $WORKFLOW_DIR/config"
    echo ""
    echo "Opening task and config files in editor..."

    # Open both files in vim with vertical split
    ${EDITOR:-vim} -O "$WORKFLOW_DIR/task.txt" "$WORKFLOW_DIR/config"
}

# =============================================================================
# Edit Subcommand - Edit Existing Workflow
# =============================================================================
edit_workflow() {
    local workflow_name="$1"

    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    # If no workflow name provided, edit project files
    if [[ -z "$workflow_name" ]]; then
        echo "Editing project configuration..."
        ${EDITOR:-vim} -O "$PROJECT_ROOT/.workflow/project.txt" "$PROJECT_ROOT/.workflow/config"
        return 0
    fi

    # Otherwise, edit workflow files
    WORKFLOW_DIR="$PROJECT_ROOT/.workflow/$workflow_name"

    # Check if workflow exists
    if [[ ! -d "$WORKFLOW_DIR" ]]; then
        echo "Error: Workflow '$workflow_name' not found"
        echo "Available workflows:"
        if list_workflows; then
            list_workflows | sed 's/^/  /'
        else
            echo "  (none)"
        fi
        echo ""
        echo "Create new workflow with: workflow new $workflow_name"
        exit 1
    fi

    echo "Editing workflow: $workflow_name"
    ${EDITOR:-vim} -O "$WORKFLOW_DIR/task.txt" "$WORKFLOW_DIR/config"
}

# =============================================================================
# List Subcommand - List All Workflows
# =============================================================================
list_workflows_cmd() {
    # Find project root
    PROJECT_ROOT=$(find_project_root) || {
        echo "Error: Not in workflow project (no .workflow/ directory found)"
        echo "Run 'workflow init' to initialize a project first"
        exit 1
    }

    echo "Workflows in $PROJECT_ROOT:"
    echo ""

    # Capture workflow list to avoid calling list_workflows twice
    local workflow_list
    workflow_list=$(list_workflows) || true

    if [[ -n "$workflow_list" ]]; then
        echo "$workflow_list" | while read -r workflow; do
            # Check if workflow has required files
            local status=""
            if [[ ! -f "$PROJECT_ROOT/.workflow/$workflow/task.txt" ]]; then
                status=" [incomplete - missing task.txt]"
            elif [[ ! -f "$PROJECT_ROOT/.workflow/$workflow/config" ]]; then
                status=" [incomplete - missing config]"
            else
                # Check for output file
                local output_file=$(ls "$PROJECT_ROOT/.workflow/output/$workflow".* 2>/dev/null | head -1)
                if [[ -n "$output_file" ]]; then
                    # Get modification time (cross-platform)
                    local output_time
                    if [[ "$(uname)" == "Darwin" ]]; then
                        output_time=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$output_file" 2>/dev/null)
                    else
                        output_time=$(stat -c "%y" "$output_file" 2>/dev/null | cut -d'.' -f1)
                    fi
                    [[ -n "$output_time" ]] && status=" [last run: $output_time]"
                fi
            fi
            echo "  $workflow$status"
        done
    else
        echo "  (no workflows found)"
        echo ""
        echo "Create a new workflow with: workflow new NAME"
    fi

    echo ""
}
