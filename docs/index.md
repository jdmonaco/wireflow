# WireFlow

**Reproducible AI Workflows for Research & Development**

Version 0.7.3 (pre-release)

## Key Features

- 🎯 **Git-like Discovery:** Run from anywhere in your project tree. WireFlow walks up to find `.workflow/` automatically.

- 📄 **Native Documents:** PDFs, Office files, images (including HEIC, TIFF, SVG) handled natively with automatic conversion.

- 📎 **Obsidian Embeds:** `![[file]]` syntax auto-resolves. Embedded images and PDFs become content blocks.

- 🧠 **Model Profiles:** Switch between `fast`, `balanced`, and `deep` tiers. Enable extended thinking or effort levels for complex tasks.

- 🔌 **Multi-Provider:** Use Anthropic Claude API or any OpenAI-compatible endpoint (LM Studio, ollama, vLLM).

- 📦 **Batch Processing:** Process hundreds of documents at 50% cost savings with the Message Batches API.

- 🔧 **Config Cascade:** Global → ancestors → project → workflow → CLI. Set once, override where needed.

- 🏗️ **Nested Projects:** Inherit settings from parent projects. Perfect for monorepos.

- 🔗 **Workflow Chains:** Build pipelines with `--depends-on`. Stale dependencies auto-execute before the target.

- 📥 **Input vs Context:** Separate primary documents from supporting materials for cleaner prompts.

- 💰 **Prompt Caching:** Smart ordering puts stable content first. Up to 90% savings on cached input tokens.

- 📚 **Citations:** Enable source attribution with `--enable-citations`. Get references you can verify.

- ⚡ **Three Modes:** Persistent workflows for iteration, quick `task` mode with hierarchical templates, or `batch` for bulk processing.

- 📺 **Streaming Output:** Watch responses generate in real-time with incremental Markdown rendering in the terminal.

- 🐚 **Shell Integration:** Bash completion, project-aware prompt (`__wfw_ps1`), and streamlined CLI.

- 💾 **Safe Outputs:** Timestamped backups, hardlinked copies, atomic writes. Never lose work.

## Quick Start

To install `wireflow`, clone the [repo](https://github.com/jdmonaco/wireflow) and run the installer:

```bash
# Clone repository
git clone https://github.com/jdmonaco/wireflow.git
cd wireflow

# Install (creates symlinks to ~/.local/bin and bash completions)
./wireflow.sh shell install
```

**For Anthropic Claude API (default):**

```bash
export ANTHROPIC_API_KEY="your-key"
export PATH="$HOME/.local/bin:$PATH"  # if not already in PATH
```

**For local LLM servers (LM Studio, ollama, etc.):**

```bash
# In ~/.config/wireflow/config
PROVIDER="openai"
OPENAI_BASE_URL="http://localhost:1234"
OPENAI_MODEL_BALANCED="your-model-name"
```

Try out initializing `wireflow` in any folder containing a project or files you want to process:

```bash
# Initialize project
cd ~/my-manuscript
wfw init .

# Create and run first workflow
wfw new 00-context-analysis
wfw run 00-context-analysis --stream
```

Your project files and folders are treated as read-only. All WireFlow files are maintained in a `.workflow/` subfolder.

## What You Can Do

**Persistent Workflows:** Create reusable workflows for iterative development:

```bash
wfw new analyze-data
wfw run analyze-data -cx "data/*.csv" --stream
```

**One-Off Tasks:** Execute lightweight tasks without workflow persistence:

```bash
wfw task -i "Extract key points" -cx notes.md
wfw task summarize -cx "*.md"
```

**Workflow Chains:** Build dependent pipelines with automatic context passing and stale dependency re-execution:

```bash
wfw run 02-analysis --depends-on 01-context --stream
```

## Use Cases

- **Research manuscripts:** Iterative analysis and writing assistance
- **Code analysis:** Systematic code review and refactoring workflows
- **Documentation:** Generate and update documentation from source code
- **Data processing:** Multi-stage data analysis pipelines
- **Content generation:** Structured content creation with context reuse

## Documentation Structure

- **[Getting Started](getting-started/installation.md):** Installation, quick start, and your first workflow
- **[User Guide](user-guide/projects.md):** Complete guide to using WireFlow effectively
- **[Reference](reference/index.md):** CLI command reference
- **[Troubleshooting](troubleshooting.md):** Common issues and solutions
- **[Developer Guide](developer-guide/index.md):** Architecture, implementation, contributing

## Requirements

- Bash 4.0+
- `curl` and `jq` for API interaction
- Anthropic API key ([get one here](https://console.anthropic.com/))

**Optional:** `glow` or `gum` for enhanced output display, `yq` for request inspection.
See [installation guide](getting-started/installation.md#optional-dependencies) for details.

## License

MIT License - see repository for details

## Getting Help

```bash
wfw help              # Show all subcommands
wfw help <subcommand> # Show detailed help for a subcommand
wfw <subcommand> -h   # Quick help for a subcommand
```

---

Ready to get started? Head to the [Installation Guide](getting-started/installation.md) →
