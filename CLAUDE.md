# AI-Driven Workflow Framework

## Project Overview

This `Work/` directory contains a bash-scripted workflow framework for AI-assisted manuscript development. The parent project is a BRAIN NeuroAI commentary manuscript developed with Jeffrey Kopsick for submission to the Journal of Neural Engineering special issue associated with the AAAI NeuroAI workshop organized by Anton Arkhipov at the Allen Institute.

The framework processes reference materials from the parent project directory, applies custom prompts and instructions, and generates structured outputs using the Anthropic Messages API.

## Directory Structure

```
Work/
├── workflow.sh                 # Unified workflow script (init + run modes)
├── config                      # Project configuration (sourced by workflow.sh)
├── prompts/
│   └── system.txt              # Generated system prompt (concatenated from config)
├── 00-workshop-context/        # Example workflow implementation
│   ├── task.txt                # Task-specific instructions
│   ├── context.txt             # Aggregated reference materials (generated)
│   ├── output.md               # API response output
│   └── run.sh                  # Workflow execution script
└── output/                     # Hardlinks to workflow outputs
    └── 00-workshop-context.md  # Hardlink to 00-workshop-context/output.md
```

## Configuration

### Project Configuration File (`config`)

The `config` file is a sourceable bash script containing project-wide settings:

```bash
# System prompts to concatenate (in order)
# Each name maps to $PROMPT_PREFIX/System/{name}.xml
SYSTEM_PROMPTS=(Root NeuroAI)

# API defaults
MODEL="claude-sonnet-4-5"
TEMPERATURE=1.0
MAX_TOKENS=4096
```

**Key features:**
- Created automatically by `workflow.sh init` if missing
- Sourced by `workflow.sh` at runtime
- Can be overridden per-workflow via command-line flags

### System Prompts

System prompts are built by concatenating XML files specified in the `SYSTEM_PROMPTS` array:
- Files are located at `$PROMPT_PREFIX/System/{name}.xml`
- `Root` prompt is the base and typically always included
- Additional prompts (e.g., `NeuroAI`) are project-specific
- Concatenated into `prompts/system.txt` before API requests

### Workflow Structure

Each workflow follows this pattern:
1. **Task Description**: Specific instructions (`<workflow>/task.txt`)
2. **Context Materials**: Aggregated references (`<workflow>/context.txt`, auto-generated)
3. **Output**: API response (`<workflow>/output.md`)
4. **Output Hardlink**: Linked in `output/` directory for easy access and workflow chaining
5. **Execution Script**: Simple wrapper (`<workflow>/run.sh`) calling `workflow.sh`

## Key Dependencies

- **External**: `curl`, `jq`, `mdformat` (optional)
- **Custom**: `filecat()` function from `~/.bash_functions` (required)
- **Environment Variables**:
  - `ANTHROPIC_API_KEY`: Messages API access
  - `PROMPT_PREFIX`: Base path to system prompt directory (e.g., `~/OneDrive/Admin/Prompts`)

## Usage

### Initialize a New Workflow

```bash
./workflow.sh init WORKFLOW_NAME
```

This creates:
1. `config` file (if missing) with default settings
2. `WORKFLOW_NAME/` directory
3. `WORKFLOW_NAME/task.txt` (from interactive input)
4. `WORKFLOW_NAME/run.sh` (stub execution script)

### Execute a Workflow

```bash
# Using workflow-specific script
cd WORKFLOW_NAME && ./run.sh

# Direct execution
./workflow.sh run --workflow WORKFLOW_NAME [options]

# Or (implicit 'run')
./workflow.sh --workflow WORKFLOW_NAME [options]
```

### Common Options

- `--stream`: Use streaming mode (default: single-batch)
- `--dry-run`: Estimate tokens without API call
- `--context-pattern PATTERN`: Glob pattern for context files
- `--context-file FILE`: Add specific file (repeatable)
- `--depends-on WORKFLOW`: Include output from another workflow
- `--model MODEL`: Override model (default from config)
- `--temperature TEMP`: Override temperature
- `--max-tokens NUM`: Override max tokens
- `--system-prompts LIST`: Override system prompts (comma-separated)

### Examples

```bash
# Initialize new workflow
./workflow.sh init 01-outline-draft

# Execute with context pattern
./workflow.sh --workflow 00-workshop-context \
  --context-pattern '../Workshops/AAAI 2026 NeuroAI Workshop - Jan 2026/*.md'

# Execute with dependencies and streaming
./workflow.sh --workflow 02-intro-draft \
  --depends-on 01-outline-draft \
  --stream

# Override system prompts for specific workflow
./workflow.sh --workflow 03-methods \
  --system-prompts "Root,DataScience,Statistics"
```

## Implementation Details

### Context Aggregation

The framework supports multiple methods for building context:

1. **Glob patterns** (`--context-pattern`): Auto-aggregate files matching pattern
   - Example: `--context-pattern '../References/*.md'`
   - Uses `filecat` with visual separators between files

2. **Explicit files** (`--context-file`): Specify exact files (repeatable)
   - Example: `--context-file ../data.md --context-file ../notes.md`
   - Maintains specified order

3. **Workflow dependencies** (`--depends-on`): Chain workflows together
   - Example: `--depends-on 01-outline-draft`
   - Reads from `output/WORKFLOW.md` hardlinks
   - Ensures workflows are executed in proper order

### Output Management

- Generated output saved to `WORKFLOW/output.md`
- Hardlink created at `output/WORKFLOW.md` for:
  - Easy browsing (visible in Finder/Obsidian)
  - Workflow chaining via `--depends-on`
- Previous outputs backed up with timestamps (YYYYMMDDHHMMSS)
- Optional `mdformat` post-processing

### Token Estimation

Token estimation uses heuristic formula: `(word_count * 1.3) + 4096`
- System prompt tokens
- Task prompt tokens
- Context prompt tokens
- Displayed before API call (useful for cost estimation)
- Use `--dry-run` to estimate without making API request

### API Request Modes

**Single-batch (default):**
- Blocks until complete
- Displays output in `less`
- More reliable for long responses

**Streaming (`--stream`):**
- Real-time terminal output
- See progress as text is generated
- Good for interactive use

## Future Enhancements

- **Multi-turn Conversations**: Support iterative refinement with conversation history
- **Template System**: Predefined task templates for common operations
- **Parallel Execution**: Run independent workflows concurrently
- **Output Validation**: Check generated content for completeness
- **DAG Visualization**: Display workflow dependency graph

## Notes

- System prompts use XML formatting for structured instructions
- The `filecat()` function adds visual separators for better context parsing
- Workflow-specific `run.sh` scripts are thin wrappers - main logic in `workflow.sh`
- Config file uses bash syntax - can include shell variables and logic if needed
