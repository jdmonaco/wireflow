#!/usr/bin/env bash
set -e

# =============================================================================
# Unified Workflow Script for AI-Assisted Manuscript Development
# =============================================================================
# This script provides a unified interface for creating and executing AI
# workflows using the Anthropic Messages API.
#
# Subcommands:
#   init NAME    Create new workflow structure with interactive setup
#   run          Execute a workflow (can be implicit)
#
# Usage:
#   ./workflow.sh init WORKFLOW_NAME
#   ./workflow.sh run --workflow WORKFLOW_NAME [options]
#   ./workflow.sh --workflow WORKFLOW_NAME [options]  # 'run' is implicit
# =============================================================================

# Import bash functions (for filecat)
if [[ -f ~/.bash_functions ]]; then
    source ~/.bash_functions
else
    echo "Error: ~/.bash_functions not found"
    exit 1
fi

# Check for required filecat function
if ! command -v filecat &>/dev/null; then
    echo "Error: filecat function not found in ~/.bash_functions"
    exit 1
fi

# Default configuration
DEFAULT_MODEL="claude-sonnet-4-5"
DEFAULT_TEMPERATURE=1.0
DEFAULT_MAX_TOKENS=4096
SYSTEM_PROMPT_FILE="prompts/system.txt"

# =============================================================================
# Help Text
# =============================================================================
show_help() {
    cat <<EOF
Usage: $0 SUBCOMMAND [OPTIONS]

SUBCOMMANDS:
    init NAME                   Initialize a new workflow with interactive setup
    run [OPTIONS]               Execute a workflow ('run' is optional)

EXECUTION OPTIONS:
    --workflow WORKFLOW_NAME    Workflow to execute (required)
    --stream                    Use streaming API mode (default: single-batch)
    --dry-run                   Estimate tokens only, don't make API call

CONTEXT AGGREGATION:
    --context-file FILE         Add specific file to context (repeatable)
    --context-pattern PATTERN   Use glob pattern for filecat aggregation
    --depends-on WORKFLOW       Include output from another workflow

API CONFIGURATION:
    --model MODEL              Claude model (default: $DEFAULT_MODEL)
    --temperature TEMP         Sampling temperature (default: $DEFAULT_TEMPERATURE)
    --max-tokens NUM           Max output tokens (default: $DEFAULT_MAX_TOKENS)
    --system-prompts LIST      Comma-separated system prompt names (overrides config)

OTHER:
    --help, -h                 Show this help message

EXAMPLES:
    # Initialize new workflow
    $0 init 01-outline-draft

    # Execute workflow with context pattern
    $0 run --workflow 00-workshop-context --context-pattern '../References/*.md'

    # Execute with dependencies and streaming (implicit 'run')
    $0 --workflow 02-intro-draft --depends-on 01-outline-draft --stream

    # Execute with explicit files
    $0 run --workflow 03-methods --context-file ../data.md --context-file ../notes.md

EOF
}

# =============================================================================
# Initialization Subcommand
# =============================================================================
init_workflow() {
    local workflow_name="$1"

    if [[ -z "$workflow_name" ]]; then
        echo "Error: Workflow name required for init subcommand"
        echo "Usage: $0 init WORKFLOW_NAME"
        exit 1
    fi

    # Create default config file if it doesn't exist
    if [[ ! -f "config" ]]; then
        cat > "config" <<'CONFIG_EOF'
# Work/config - Project configuration

# System prompts to concatenate (in order)
# Each name maps to $PROMPT_PREFIX/System/{name}.xml
SYSTEM_PROMPTS=(Root NeuroAI)

# API defaults
MODEL="$DEFAULT_MODEL"
TEMPERATURE=$DEFAULT_TEMPERATURE
MAX_TOKENS=$DEFAULT_MAX_TOKENS
CONFIG_EOF
        echo "Created default config file: config"
    fi

    # Create workflow directory
    if [[ ! -d "$workflow_name" ]]; then
        mkdir -p "$workflow_name"
        echo "Created workflow directory: $workflow_name/"
    else
        echo "Workflow directory already exists: $workflow_name/"
    fi

    # Interactive task description input
    echo ""
    echo "Enter task description (press Ctrl-D when finished):"
    echo "---"
    local task_content
    task_content=$(cat)

    # Write task file
    echo "$task_content" > "$workflow_name/task.txt"
    echo ""
    echo "Created: $workflow_name/task.txt"

    # Generate stub workflow script
    local stub_script="$workflow_name/run.sh"
    cat > "$stub_script" <<'STUB_EOF'
#!/usr/bin/env bash
set -e

# Workflow configuration
WORKFLOW_NAME="WORKFLOW_NAME_PLACEHOLDER"

# Context aggregation
# Choose one or more methods:

# Method 1: Glob pattern for auto-aggregation
# CONTEXT_PATTERN="../References/*.md"

# Method 2: Explicit file list
# CONTEXT_FILES=(
#     "../References/document1.md"
#     "../References/document2.md"
# )

# Method 3: Depend on previous workflow outputs
# DEPENDS_ON=(
#     "00-workshop-context"
#     "01-outline-draft"
# )

# API configuration (optional workflow-specific overrides)
# Note: Default values are set in ../config
# Uncomment to override for this workflow only:
# MODEL="claude-sonnet-4-5"
# TEMPERATURE=1.0
# MAX_TOKENS=4096
# SYSTEM_PROMPTS="Root,NeuroAI,DataScience"

# Build command
CMD="../workflow.sh run --workflow $WORKFLOW_NAME"

# Add context options
if [[ -n "$CONTEXT_PATTERN" ]]; then
    CMD="$CMD --context-pattern '$CONTEXT_PATTERN'"
fi

if [[ -n "$CONTEXT_FILES" ]]; then
    for file in "${CONTEXT_FILES[@]}"; do
        CMD="$CMD --context-file '$file'"
    done
fi

if [[ -n "$DEPENDS_ON" ]]; then
    for dep in "${DEPENDS_ON[@]}"; do
        CMD="$CMD --depends-on '$dep'"
    done
fi

# Add API config overrides (if set)
[[ -n "$MODEL" ]] && CMD="$CMD --model $MODEL"
[[ -n "$TEMPERATURE" ]] && CMD="$CMD --temperature $TEMPERATURE"
[[ -n "$MAX_TOKENS" ]] && CMD="$CMD --max-tokens $MAX_TOKENS"
[[ -n "$SYSTEM_PROMPTS" ]] && CMD="$CMD --system-prompts $SYSTEM_PROMPTS"

# Add streaming flag if desired
# CMD="$CMD --stream"

# Execute
eval $CMD
STUB_EOF

    # Replace placeholder with actual workflow name
    sed -i '' "s/WORKFLOW_NAME_PLACEHOLDER/$workflow_name/g" "$stub_script"

    # Make executable
    chmod +x "$stub_script"
    echo "Created: $stub_script"

    # Open in editor
    echo ""
    echo "Opening workflow script in editor..."
    local editor="${EDITOR:-vim}"
    $editor "$stub_script"

    echo ""
    echo "Workflow '$workflow_name' initialized successfully!"
    echo "Edit $stub_script to configure context sources and run the workflow."
}

# =============================================================================
# Parse Subcommand
# =============================================================================

# Check for help first
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Check for init subcommand
if [[ "$1" == "init" ]]; then
    init_workflow "$2"
    exit 0
fi

# Check for explicit run subcommand (and skip it)
if [[ "$1" == "run" ]]; then
    shift
fi

# Otherwise, proceed with execution mode (implicit run)

# =============================================================================
# Load Project Configuration
# =============================================================================

# Set defaults first
SYSTEM_PROMPTS=(Root)
MODEL="$DEFAULT_MODEL"
TEMPERATURE="$DEFAULT_TEMPERATURE"
MAX_TOKENS="$DEFAULT_MAX_TOKENS"

# Source config file if it exists (overrides defaults)
if [[ -f "config" ]]; then
    source config
fi

# =============================================================================
# Execution Mode - Argument Parsing
# =============================================================================
WORKFLOW_NAME=""
STREAM_MODE=false
DRY_RUN=false
CONTEXT_FILES=()
CONTEXT_PATTERN=""
DEPENDS_ON=()
SYSTEM_PROMPTS_OVERRIDE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --workflow)
            WORKFLOW_NAME="$2"
            shift 2
            ;;
        --stream)
            STREAM_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --context-file)
            CONTEXT_FILES+=("$2")
            shift 2
            ;;
        --context-pattern)
            CONTEXT_PATTERN="$2"
            shift 2
            ;;
        --depends-on)
            DEPENDS_ON+=("$2")
            shift 2
            ;;
        --model)
            MODEL="$2"
            shift 2
            ;;
        --temperature)
            TEMPERATURE="$2"
            shift 2
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --system-prompts)
            SYSTEM_PROMPTS_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Handle --system-prompts override (comma-separated list)
if [[ -n "$SYSTEM_PROMPTS_OVERRIDE" ]]; then
    IFS=',' read -ra SYSTEM_PROMPTS <<< "$SYSTEM_PROMPTS_OVERRIDE"
fi

# Validate execution mode requirements
if [[ -z "$WORKFLOW_NAME" ]]; then
    echo "Error: --workflow required for execution mode"
    echo "Use --help for usage information"
    exit 1
fi

# =============================================================================
# Execution Mode - Setup
# =============================================================================

# Validate workflow directory exists
if [[ ! -d "$WORKFLOW_NAME" ]]; then
    echo "Error: Workflow directory not found: $WORKFLOW_NAME"
    echo "Use '$0 init $WORKFLOW_NAME' to create a new workflow"
    exit 1
fi

# File paths
TASK_PROMPT_FILE="$WORKFLOW_NAME/task.txt"
CONTEXT_PROMPT_FILE="$WORKFLOW_NAME/context.txt"
OUTPUT_FILE="$WORKFLOW_NAME/output.md"
OUTPUT_LINK="output/${WORKFLOW_NAME}.md"

# Check if task file exists
if [[ ! -f "$TASK_PROMPT_FILE" ]]; then
    echo "Error: Task file not found: $TASK_PROMPT_FILE"
    exit 1
fi

# Create system prompt if needed
if [[ -z "$PROMPT_PREFIX" ]]; then
    echo "Error: PROMPT_PREFIX environment variable is not set"
    echo "Set PROMPT_PREFIX to the directory containing your System/*.xml prompt files"
    exit 1
fi

PROMPTDIR="$PROMPT_PREFIX/System"
if [[ ! -f "$SYSTEM_PROMPT_FILE" ]]; then
    if [[ ! -d "$PROMPTDIR" ]]; then
        echo "Error: System prompt directory not found: $PROMPTDIR"
        exit 1
    fi

    mkdir -p "$(dirname "$SYSTEM_PROMPT_FILE")"

    # Build system prompt from SYSTEM_PROMPTS array
    > "$SYSTEM_PROMPT_FILE"
    for prompt_name in "${SYSTEM_PROMPTS[@]}"; do
        prompt_file="$PROMPTDIR/${prompt_name}.xml"
        if [[ ! -f "$prompt_file" ]]; then
            echo "Error: System prompt file not found: $prompt_file"
            exit 1
        fi
        cat "$prompt_file" >> "$SYSTEM_PROMPT_FILE"
    done

    echo "Created system prompt: $SYSTEM_PROMPT_FILE (from: ${SYSTEM_PROMPTS[*]})"
fi

# =============================================================================
# Context Aggregation
# =============================================================================

echo "Building context..."

# Start with empty context
> "$CONTEXT_PROMPT_FILE"

# Add files from --depends-on (from output/ directory)
if [[ ${#DEPENDS_ON[@]} -gt 0 ]]; then
    echo "  Adding dependencies..."
    for dep in "${DEPENDS_ON[@]}"; do
        dep_file="output/${dep}.md"
        if [[ ! -f "$dep_file" ]]; then
            echo "Error: Dependency output not found: $dep_file"
            echo "Ensure workflow '$dep' has been executed successfully"
            exit 1
        fi
        echo "    - $dep"
        filecat "$dep_file" >> "$CONTEXT_PROMPT_FILE"
    done
fi

# Add files from --context-pattern
if [[ -n "$CONTEXT_PATTERN" ]]; then
    echo "  Adding files from pattern: $CONTEXT_PATTERN"
    eval "filecat $CONTEXT_PATTERN" >> "$CONTEXT_PROMPT_FILE"
fi

# Add explicit files from --context-file
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
    echo "  Adding explicit files..."
    for file in "${CONTEXT_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Error: Context file not found: $file"
            exit 1
        fi
        echo "    - $file"
        filecat "$file" >> "$CONTEXT_PROMPT_FILE"
    done
fi

# Check if any context was provided
if [[ ! -s "$CONTEXT_PROMPT_FILE" ]]; then
    echo "Warning: No context provided. Task will run without context."
    echo "  Use --context-file, --context-pattern, or --depends-on to add context"
fi

# =============================================================================
# Token Estimation
# =============================================================================

SYSWC=$(wc -w < "$SYSTEM_PROMPT_FILE")
SYSTC=$((SYSWC * 13 / 10 + 4096))
echo "Estimated system tokens: $SYSTC"

TASKWC=$(wc -w < "$TASK_PROMPT_FILE")
TASKTC=$((TASKWC * 13 / 10 + 4096))
echo "Estimated task tokens: $TASKTC"

if [[ -s "$CONTEXT_PROMPT_FILE" ]]; then
    CONTEXTWC=$(wc -w < "$CONTEXT_PROMPT_FILE")
    CONTEXTTC=$((CONTEXTWC * 13 / 10 + 4096))
    echo "Estimated context tokens: $CONTEXTTC"
else
    CONTEXTTC=0
fi

TOTAL_INPUT_TOKENS=$((SYSTC + TASKTC + CONTEXTTC))
echo "Estimated total input tokens: $TOTAL_INPUT_TOKENS"
echo ""

# Exit if dry-run
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry-run mode: Stopping before API call"
    exit 0
fi

# =============================================================================
# API Request Setup
# =============================================================================

API_KEY="${ANTHROPIC_API_KEY}"

# Check if API key is set
if [[ -z "$API_KEY" ]]; then
    echo "Error: ANTHROPIC_API_KEY environment variable is not set"
    exit 1
fi

# Read prompt files
SYSTEM_PROMPT=$(<"$SYSTEM_PROMPT_FILE")

# Combine context and task for user prompt
if [[ -s "$CONTEXT_PROMPT_FILE" ]]; then
    USER_PROMPT="$(filecat "$CONTEXT_PROMPT_FILE" "$TASK_PROMPT_FILE")"
else
    USER_PROMPT=$(<"$TASK_PROMPT_FILE")
fi

# Escape JSON strings
escape_json() {
    local string="$1"
    printf '%s' "$string" | jq -Rs .
}

SYSTEM_JSON=$(escape_json "$SYSTEM_PROMPT")
USER_JSON=$(escape_json "$USER_PROMPT")

# Build JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "model": "$MODEL",
  "max_tokens": $MAX_TOKENS,
  "temperature": $TEMPERATURE,
  "system": $SYSTEM_JSON,
  "messages": [
    {
      "role": "user",
      "content": $USER_JSON
    }
  ]
}
EOF
)

# Backup any previous output files
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "Backing up previous output file..."
    OUTPUT_BAK="${OUTPUT_FILE%.*}-$(date +"%Y%m%d%H%M%S").${OUTPUT_FILE##*.}"
    mv -v "$OUTPUT_FILE" "$OUTPUT_BAK"
    echo ""
fi

# =============================================================================
# API Request Execution
# =============================================================================

if [[ "$STREAM_MODE" == true ]]; then
    # Streaming mode
    echo "Sending Messages API request (streaming)..."
    echo "---"
    echo ""

    # Initialize output file
    > "$OUTPUT_FILE"

    curl -Ns https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$(echo "$JSON_PAYLOAD" | jq '. + {stream: true}')" | while IFS= read -r line; do
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
                        printf '%s' "$delta_text" >> "$OUTPUT_FILE"
                    fi
                    ;;
                "message_stop")
                    printf '\n'
                    ;;
                "error")
                    echo ""
                    echo "API Error:"
                    echo "$json_data" | jq '.error'
                    exit 1
                    ;;
            esac
        fi
    done

    echo ""
    echo "---"

else
    # Single-batch mode
    echo -n "Sending Messages API request... "

    response=$(curl -s https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$JSON_PAYLOAD")

    echo "done!"

    # Check for errors
    if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
        echo "API Error:"
        echo "$response" | jq '.error'
        exit 1
    fi

    # Extract and save response
    echo "$response" | jq -r '.content[0].text' > "$OUTPUT_FILE"

    # Display with less
    less "$OUTPUT_FILE"
fi

# =============================================================================
# Post-Processing
# =============================================================================

echo "Response saved to: $OUTPUT_FILE"

# Create/update hardlink in output directory
mkdir -p output
if [[ -f "$OUTPUT_LINK" ]]; then
    rm "$OUTPUT_LINK"
fi
ln "$OUTPUT_FILE" "$OUTPUT_LINK"
echo "Hardlink created: $OUTPUT_LINK"

# Format Markdown output files
if [[ -f "$OUTPUT_FILE" && "$OUTPUT_FILE" == *.md ]] && command -v mdformat &>/dev/null; then
    echo "Formatting output with mdformat..."
    mdformat --no-validate "$OUTPUT_FILE"
fi

echo ""
echo "Workflow '$WORKFLOW_NAME' completed successfully!"
