# WireFlow: Reproducible AI Workflows for Research and Development

**Version:** 0.3.0 (pre-release)

A terminal-based tool for building reproducible AI workflows for research, development, and analysis, featuring flexible configuration cascades, comprehensive document processing (PDFs, Office files, images), workflow dependencies and chaining, and intelligent context management.

## Key Features

- 🎯 **Git-like Project Discovery:** Automatic `.workflow/` directory detection walking up from any subdirectory, enabling project-aware execution from anywhere in your tree (stops at `$HOME` for safety).
- 📄 **Native Document Processing:** Unified handling of PDFs (32MB, joint text+visual analysis), Microsoft Office files (.docx/.pptx auto-converted via LibreOffice), images (Vision API with automatic resizing), and text files with intelligent format detection and caching.
- 🔧 **Configuration Cascade with Pass-Through:** Multi-tier inheritance (global → ancestors → project → workflow → CLI) where empty values automatically inherit from parent tiers while explicit values override and decouple, enabling change-once affect-many configuration management.
- 🏗️ **Nested Project Support:** Automatic discovery and inheritance from all ancestor projects in the directory hierarchy, with transparent source tracking showing exactly where each configuration value originates.
- 🔗 **Workflow Dependencies & Chaining:** Create multi-stage processing pipelines with `DEPENDS_ON` declarations, automatically passing outputs as context to dependent workflows via hardlinks for efficient DAG-based orchestration.
- 📦 **Semantic Content Aggregation:** Distinguish INPUT documents (primary analysis targets) from CONTEXT materials (supporting information) using three methods: glob patterns, explicit file lists, and workflow dependencies, with optimized ordering for cost-effective caching.
- 💰 **Prompt Caching Architecture:** Strategic cache breakpoint placement (max 4) at semantic boundaries enables 90% cost reduction on stable content, with intelligent ordering (system prompts → project descriptions → PDFs → text → images → task) and date-only timestamps to prevent minute-by-minute invalidation.
- 📚 **Citations Support:** Optional Anthropic citations API integration with document mapping for source attribution, generating sidecar citation files and enabling proper references for AI-generated content.
- ⚡ **Dual Execution Modes:** Persistent workflows with configuration, context, dependencies, and outputs for iterative development, or lightweight task mode for one-off queries without workflow directories, both sharing optimized execution logic.
- 💾 **Safe Output Management:** Automatic timestamped backups before overwriting, hardlinked copies for convenient access (`.workflow/output/`), atomic file operations, and format-specific post-processing (mdformat, jq).
- 📊 **Dual Token Estimation:** Fast heuristic character-based estimates plus exact counts via Anthropic's Token Counting API, with detailed breakdowns showing contribution from system prompts, task, input documents, context, and images.
- 🌊 **Streaming & Batch Modes:** Real-time streaming output with SSE parsing for immediate feedback, or single-request batch mode with pager display, both supporting identical configuration and context aggregation.

## Quick Start

### Install

First, clone the [repo](https://github.com/jdmonaco/wireflow) and then link the script into your `PATH`. For example:

```bash
# Clone repository
git clone https://github.com/jdmonaco/wireflow.git
cd wireflow

# Add to PATH (example using ~/.local/bin)
ln -s "$(pwd)/wireflow.sh" ~/.local/bin/wfw
```

### Setup

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export PATH="$HOME/.local/bin:$PATH"
```

### Create Your First Workflow

```bash
# Initialize project
cd my-project
wfw init .

# Create workflow
wfw new analyze-data

# Edit workflow config
wfw edit analyze-data

# Run with context
wfw run analyze-data --context-file data.csv --stream
```

Your project files and folders are treated as read-only. All WireFlow files are maintained in a `.workflow/` subfolder.

## Documentation

**📚 Complete documentation:** [https://docs.joemona.co/wireflow/](https://docs.joemona.co/wireflow/)

### Quick Links

- **[Installation Guide](https://docs.joemona.co/wireflow/getting-started/installation/):** Detailed setup instructions
- **[Quick Start Guide](https://docs.joemona.co/wireflow/getting-started/quickstart/):** Get running in 5 minutes
- **[User Guide](https://docs.joemona.co/wireflow/user-guide/initialization/):** Complete usage documentation
- **[CLI Reference](https://docs.joemona.co/wireflow/reference/cli-reference/):** All commands and options
- **[Examples](https://docs.joemona.co/wireflow/user-guide/examples/):** Real-world usage patterns
- **[Troubleshooting](https://docs.joemona.co/wireflow/troubleshooting/):** Common issues and solutions

## Core Concepts

### Workflows

Persistent, named tasks with configuration and outputs:

```bash
wfw new 01-analysis
wfw run 01-analysis --stream
```

### Tasks

Lightweight, one-off execution without persistence:

```bash
wfw task -i "Summarize these notes" --context-file notes.md
```

### Dependencies

Chain workflows to build pipelines:

```bash
wfw run 02-report --depends-on 01-analysis --stream
```

### Configuration

Multi-tier cascade with pass-through:

```
Global (~/.config/wireflow/config)
    ↓
Ancestor Projects (grandparent → parent)
    ↓
Project (.workflow/config)
    ↓
Workflow (.workflow/<workflow_name>/config)
    ↓
CLI Flags (--model, --temperature, etc.)
```

## Usage Examples

### Simple Analysis

```bash
wfw init my-analysis
wfw new analyze-data
wfw run analyze-data --context-file data.csv --stream
```

### Workflow Chain

```bash
wfw run 00-context --stream
wfw run 01-outline --depends-on 00-context --stream
wfw run 02-draft --depends-on 00-context,01-outline --stream
```

### Quick Query

```bash
wfw task -i "Extract action items" --context-file meeting-notes.md
```

## Requirements

- Bash 4.0+
- `curl` and `jq`
- Anthropic API key ([get one here](https://console.anthropic.com/))

## Configuration

### Global Configuration

Auto-created on first use at `~/.config/wireflow/`:

- `config` - Global defaults for all projects
- `prompts/base.txt` - Default system prompt
- `tasks/` - Named task templates (optional)

### Project Configuration

Created by `wfw init`:

- `.workflow/config` - Project-level settings
- `.workflow/project.txt` - Project description (optional)
- `.workflow/<workflow-name>/` - Individual workflows

## Help

```bash
wfw help              # Show all subcommands
wfw help <subcommand> # Detailed subcommand help
wfw <subcommand> -h   # Quick help
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](https://docs.joemona.co/wireflow/contributing/) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Resources

- **GitHub:** [https://github.com/jdmonaco/wireflow](https://github.com/jdmonaco/wireflow)
- **Issues:** [GitHub Issues](https://github.com/jdmonaco/wireflow/issues)
- **Anthropic API:** [https://docs.anthropic.com/](https://docs.anthropic.com/)
- **Technical Details:** [CLAUDE.md](CLAUDE.md)

---

Made with [Claude Code](https://claude.com/claude-code)
