# Release Notes

## Version 0.7.1 (2025-12-01)

**Rich Markdown Rendering for Streaming Output**

This release adds a streaming markdown renderer that formats API responses in real-time when running in a terminal.

### ✨ Formatted Terminal Output

Streaming responses now display with rich markdown formatting:

- **Headers** styled with color-coded levels
- **Code blocks** with syntax highlighting
- **Lists, bold, italic** properly rendered
- **Thinking blocks** displayed dimmed (bypass renderer)

The renderer activates automatically when stdout is a terminal. Piped or redirected output remains raw markdown for compatibility with tools like `mdformat`.

### 🔧 Zero-Config Dependencies

The renderer uses Python's `rich` library with automatic installation via `uv`:

- First run: ~1-2 second delay as `uv` caches `rich`
- Subsequent runs: instant startup
- Fallback: raw output with helpful tip if `uv` not available

### 📦 Technical Details

- FIFO-based architecture for reliable streaming through subshells
- Works with both Anthropic and OpenAI providers
- New `lib/output.sh` module with `init_md_renderer()`, `stream_to_console()`, `cleanup_md_renderer()`
- Renderer script at `bin/md-render` using PEP 723 inline metadata

---

## Version 0.7.0 (2025-12-01)

**Multi-Provider Support: Run Local LLMs with OpenAI-Compatible APIs**

This release adds support for OpenAI-compatible API endpoints, enabling WireFlow to work with local LLM servers like LM Studio, ollama, and vLLM alongside the default Anthropic Claude API.

### 🔌 OpenAI-Compatible Provider

Use any OpenAI API-compatible endpoint for local or self-hosted inference:

```bash
# ~/.config/wireflow/config
PROVIDER="openai"
OPENAI_BASE_URL="http://localhost:1234/v1"
OPENAI_MODEL_BALANCED="qwen2.5-14b"
```

Supported servers:

- **LM Studio** - Desktop app with one-click local LLM serving
- **ollama** - Lightweight local LLM runner
- **vLLM** - High-throughput production serving
- Any OpenAI `/v1/chat/completions` compatible endpoint

### 🧠 Provider-Specific Model Profiles

The profile system (`fast`/`balanced`/`deep`) works with both providers:

```bash
# Anthropic models (default)
MODEL_FAST=claude-haiku-4-5
MODEL_BALANCED=claude-sonnet-4-5
MODEL_DEEP=claude-opus-4-5

# OpenAI-compatible models
OPENAI_MODEL_FAST=phi-4-mini
OPENAI_MODEL_BALANCED=qwen2.5-14b
OPENAI_MODEL_DEEP=qwen2.5-72b
```

### 📄 Automatic PDF Conversion

PDFs are automatically converted to page images when using the OpenAI provider (which lacks native PDF support):

- Uses `pdftoppm` from poppler-utils
- Cached conversions for efficiency
- Each page becomes an image content block for vision-capable models

### ⚠️ Feature Compatibility

Some Anthropic-specific features are gracefully handled:

| Feature | OpenAI Provider |
|---------|-----------------|
| Extended thinking | Warned, skipped |
| Effort parameter | Warned, skipped |
| Citations | Disabled with warning |
| Prompt caching | Silently ignored |
| Batch API | Not supported |

---

## Version 0.6.0 (2025-11-29)

**Shell Integration, Obsidian Embeds & Automatic Dependencies**

This release adds seamless shell integration for prompt customization, Obsidian markdown embed support, and intelligent workflow caching with automatic dependency execution.

### 🐚 Shell Integration

Install WireFlow into your shell environment with a single command:

```bash
wfw shell install    # Install wfw command, completions, and prompt helper
wfw shell doctor     # Check installation status and fix issues
wfw shell uninstall  # Remove shell integration
```

Customize your PS1 prompt with workflow-aware status:

```bash
source ~/.local/share/wireflow/wfw-prompt.sh
PS1='$(__wfw_ps1) \$ '  # Shows current workflow context
```

### 📎 Obsidian Embed Support

Use Obsidian's `![[file]]` syntax directly in task files:

- `![[document.pdf]]` - Embeds PDF as content block
- `![[image.png]]` - Embeds image via Vision API
- `![[notes.md]]` - Inlines markdown content
- Recursive embed resolution with cycle detection

Perfect for researchers using Obsidian as a knowledge base.

### 🔗 Automatic Dependency Execution

Workflows with `DEPENDS_ON` now auto-execute stale dependencies:

```bash
wfw run analysis  # Automatically runs prerequisite workflows first
```

Features:

- Execution caching with hash-based staleness detection
- Config/context/task changes trigger re-execution
- Topological ordering ensures correct execution sequence

### 📥 Multi-Argument Options

Simplified file specification with multiple arguments per option:

```bash
# Multiple inputs in one flag
wfw run analysis -in file1.txt file2.txt file3.txt

# Multiple context files
wfw run summary -cx ref1.pdf ref2.pdf

# Mix with other options
wfw run report -in data.csv -cx guide.md --profile deep
```

---

## Version 0.5.0 (2025-11-28)

**Batch Processing, Model Profiles & Image Format Conversion**

This release adds three major capabilities: bulk document processing with the Message Batches API, intelligent model selection with profiles, and expanded image format support with automatic conversion.

### 📦 Message Batches API

Process hundreds of documents at 50% cost savings using the new `wfw batch` subcommand:

```bash
wfw batch submit my-workflow      # Submit batch job
wfw batch status my-workflow      # Check progress
wfw batch results my-workflow     # Retrieve outputs
```

Batches run asynchronously with up to 24-hour processing windows. Ideal for large-scale document analysis, bulk transformations, and overnight processing jobs.

### 🧠 Model Profiles & Extended Thinking

Switch between reasoning modes with the new `--profile` flag:

- **fast**: Quick responses with Haiku
- **balanced**: Default quality with Sonnet (default)
- **deep**: Maximum reasoning with Opus

Enable extended thinking for complex analytical tasks:

```bash
wfw run analysis --profile deep --thinking-budget 10000
```

Also supports the `EFFORT=high` parameter for Claude Opus 4.5's enhanced reasoning.

### 📄 Image Format Conversion

Expanded Vision API support with automatic format conversion:

- **HEIC/HEIF → JPEG**: iPhone photos converted seamlessly (macOS `sips` fallback)
- **TIFF/TIF → PNG**: Lossless preservation for archival images
- **SVG → PNG**: Vector graphics rasterized at optimal resolution

All conversions are cached at the project level for efficiency.

### 🔧 CLI Improvements

Simplified input/context file specification:

```bash
# New shorthand flags
wfw run analysis -in data.csv -cx reference.pdf

# Glob patterns work too
wfw run summary -in "docs/*.md" -cx "examples/*.json"
```

---

## Version 0.4.0 (2025-11-25)

**Test Suite Overhaul & Documentation Refresh**

This release focuses on maintainability and developer experience with a complete test suite reorganization and streamlined documentation across all user-facing content.

### 🧪 Test Suite Migration

Complete restructure from flat file organization (280+ tests in 17 files) to a lean unit/integration architecture (~137 tests in 15 files).

**New Structure:**
```
tests/
├── unit/                   # Function-level tests (95 tests)
│   ├── api.bats           # API validation, citations
│   ├── config.bats        # Config loading, cascade
│   ├── core.bats          # Task file resolution
│   ├── edit.bats          # Editor detection
│   ├── execute.bats       # Dependency resolution
│   ├── help.bats          # Help output
│   └── utils.bats         # Path/file utilities
├── integration/            # End-to-end tests (42 tests)
│   ├── cat.bats, config.bats, help.bats
│   ├── init.bats, list.bats, new.bats
│   ├── run.bats           # Run mode (16 tests)
│   └── task.bats          # Task mode (5 tests)
├── test_helper/            # Enhanced helpers
│   ├── common.bash, mock_env.sh
│   ├── fixtures.sh, assertions.sh
│   └── bats-*/            # Submodules
└── run-tests.sh            # Test runner
```

**Benefits:**
- 50% fewer tests with equivalent coverage
- One unit test file per lib/*.sh module
- One integration test file per CLI command
- Faster test runs, easier maintenance
- Test runner with `unit`, `integration`, `all`, `quick` commands

### 📝 Documentation Refresh

**Punchier Key Features:** Replaced verbose multi-sentence descriptions with concise one-liners across README.md and docs/index.md.

Before:
> "Automatic `.workflow/` directory detection walking up from any subdirectory, enabling project-aware execution from anywhere in your tree (stops at `$HOME` for safety)."

After:
> "Run from anywhere in your project tree. WireFlow walks up to find `.workflow/` automatically."

**Streamlined CLI Help:** Updated all `show_help_*` functions with action-oriented descriptions and consistent `--long, -s` option formatting.

**Documentation Updates:**
- Contributing guides updated for new test structure
- CLI reference streamlined
- Configuration docs refreshed
- All workflow paths corrected to `.workflow/run/<name>/`

### 🔧 Library Refactors

Multiple `lib/*.sh` modules received bug fixes and cleanup:
- `lib/execute.sh`: Fixed circular dependency handling
- `lib/config.sh`: Improved cascade behavior
- `lib/task.sh`: Critical fixes for task mode
- `lib/api.sh`: Better error handling
- `lib/utils.sh`: Path resolution improvements

### 📦 New: Bash Completion

Added `share/bash-completion.bash` for command-line completion support.

---

## Version 0.3.0 (2025-11-20)

**Project Renamed: Workflow → WireFlow**

This release represents a major milestone with the project rebrand to **WireFlow** (command: `wfw`), alongside significant new features including built-in task templates, intelligent prompt/task fallback search, adaptive cache optimization, and automatic workflow context orientation.

### 🎯 Project Rebrand: WireFlow

The tool has been renamed from "Workflow" to "WireFlow" with `wfw` as the standard command alias for a distinctive, searchable identity without namespace collisions.

**Breaking Changes:**
- Command: `workflow` → `wireflow` (use alias `wfw` for convenience)
- Script: `workflow.sh` → `wireflow.sh`
- Environment variables: `WORKFLOW_*_PREFIX` → `WIREFLOW_*_PREFIX`
- GitHub repo: `github.com/jdmonaco/workflow` → `github.com/jdmonaco/wireflow`

**Migration:**
```bash
# Update symlink
ln -s $(pwd)/wireflow.sh ~/.local/bin/wfw

# Add alias (optional, for muscle memory)
echo "alias wfw='wireflow'" >> ~/.bashrc

# Update environment variables (if customized)
export WIREFLOW_PROMPT_PREFIX="$HOME/custom/prompts"
export WIREFLOW_TASK_PREFIX="$HOME/custom/tasks"
```

**Preserved:** `.workflow/` directories, `~/.config/wireflow/` config location continue working unchanged.

### ✨ Built-In Task Templates

Eight carefully designed generic task templates provide immediate value for common research and development workflows. Templates are created automatically in `~/.config/wireflow/tasks/` on first use.

**Templates:**
- `summarize`: Concise summary with key points and action items
- `extract`: Extract specific information, quotes, data, references
- `analyze`: Deep analysis identifying patterns and insights
- `review`: Critical evaluation with strengths/weaknesses
- `compare`: Side-by-side comparison with trade-offs
- `outline`: Generate structured hierarchical outline
- `explain`: Simplify complex topics with examples
- `critique`: Identify problems, gaps, improvements

**Discovery:**
```bash
wfw tasks                    # List all templates
wfw tasks show summarize     # Preview in pager
wfw tasks edit summarize     # Customize template
```

**Usage:**
```bash
# Execute template
wfw task summarize --context-file paper.pdf

# Create workflow from template
wfw new analysis --task summarize
```

**Benefits:**
- Immediate productivity for new users
- Consistent task structure across projects
- Fully customizable (edit templates or create your own)
- XML skeleton format matches workflow task.txt structure

### 🔍 Intelligent Fallback Search

When using custom `WIREFLOW_PROMPT_PREFIX` or `WIREFLOW_TASK_PREFIX`, the tool now automatically searches default locations (`~/.config/wireflow/prompts/`, `~/.config/wireflow/tasks/`) as fallback, preserving access to built-in prompts and templates.

**Problem Solved:**
- Setting custom PREFIX no longer breaks access to built-in "base" system prompt
- Custom task locations preserve access to all 8 built-in templates
- No need to manually copy built-ins to custom directories

**Behavior:**
- Custom location searched first (allows overriding built-ins)
- Default location searched as fallback
- `wfw tasks` shows templates from both locations
- Custom templates override built-ins with same name

**Benefits:**
- No breakage when customizing PREFIX locations
- Layered template system (custom + built-in)
- Zero configuration required for most users

### 💰 Adaptive Cache-Control Strategy

Sophisticated content-aware cache breakpoint placement maximizes prompt caching efficiency while respecting Anthropic's 4-breakpoint API limit.

**Architecture:**
- Content-type detection (PDFs, text documents, images)
- Strategic breakpoint placement at semantic boundaries
- Adaptive strategy based on content mix
- 90% cost reduction on cached content

**Strategy:**
- System: 2 breakpoints (user prompts, project description)
- User: Up to 2 adaptive breakpoints based on content:
  - PDFs exist: after last PDF, then after images OR text
  - No PDFs: after last text, then after images
  - Only task: no breakpoints (re-processed each run)

**Fixes:**
- Images now properly cached (was missing entirely)
- Per-section caching replaced with adaptive strategy
- Never exceeds 4-breakpoint limit (was violating with 5+ breakpoints)

**Test Coverage:** 14/14 cache-control tests passing (100%)

### 🧭 Meta System Prompt

Automatic workflow context orientation prompt included as first block in every API request, helping AI assistants understand the workflow structure, content organization, and project hierarchy.

**Implementation:**
- Created automatically at `~/.config/wireflow/prompts/meta.txt`
- Always included first (before user prompts)
- Not user-configurable (internal implementation)
- No cache_control (too small ~50 tokens, below 1024 minimum)
- Describes system/user block structure, XML metadata, content types

**Benefits:**
- Better AI understanding of workflow context
- Modular design (separate block, easy to update)
- No cache budget impact (uncached by design)
- Transparent to users

### 📚 Documentation Improvements

**CLAUDE.md Refactoring:**
- Split 1,333-line file into 3 focused documents (74% reduction)
- CLAUDE.md (346 lines): Development workflows and processes
- docs/contributing/architecture.md (419 lines): System design
- docs/contributing/implementation.md (493 lines): Technical details
- Faster AI context loading, better organization

**Features Documentation:**
- Updated Key Features in README.md and docs/index.md
- 12 accurate features highlighting innovations
- Removed outdated claims, added quantified benefits
- Consistent between both files

**Contributing Docs:**
- Streamlined contributing/index.md (60% smaller)
- Added architecture and implementation to navigation
- Better contributor onboarding journey

### 🧪 Testing Enhancements

- Added cache-control.bats (14 tests, 100% passing)
- Added tasks.bats (11 tests for template system)
- Test suite performance guidelines (avoid repeated full runs)
- Total: 290+ tests

### Target Users

**Research and development workflows** requiring:
- Document analysis and synthesis
- Multi-stage processing pipelines
- Reproducible AI-assisted content generation
- Cost-effective prompt caching
- Template-based workflow creation

---

## Version 0.2.0 (2025-01-20)

This release marks a significant milestone with comprehensive document processing capabilities and architectural maturity.

### Major Features

- **PDF Document Support:** Native processing via Claude API with joint text and visual analysis (32MB limit)
- **Microsoft Office Support:** Automatic conversion of .docx and .pptx files with intelligent caching
- **Image Processing:** Vision API integration with automatic resizing and validation
- **Enhanced Documentation:** Complete user guides for document types and LibreOffice setup

### Core Architecture & Unique Innovations

#### 1. Git-like Project Discovery with Configuration Cascade

The tool implements a sophisticated multi-tier configuration cascade (global → ancestors → project → workflow → CLI) with **pass-through inheritance**. Empty values automatically inherit from parent tiers, while explicit values override and become decoupled. This enables centralized defaults that cascade down but can be overridden at any level. Nested projects automatically inherit ALL ancestor configurations in the hierarchy.

**Innovation:** Unlike most tools with simple config hierarchies, this provides transparent inheritance where changing a global default automatically affects all empty configs downstream.

#### 2. Semantic Content Separation

Distinguishes between **INPUT documents** (primary materials to analyze/transform) and **CONTEXT materials** (supporting information) with three aggregation methods: glob patterns, explicit file lists, and workflow dependencies.

**Innovation:** This semantic separation enables precise control over what the AI analyzes vs what provides background, with automatic ordering optimization.

#### 3. Workflow Chaining and Dependencies

Workflows can declare dependencies on other workflow outputs via `DEPENDS_ON`. Outputs are managed via hardlinks for efficient storage and atomic updates. Cross-format dependencies work seamlessly (JSON → Markdown → HTML pipelines).

**Innovation:** Creates a DAG of processing stages where outputs automatically feed as context into dependent workflows, enabling complex multi-stage pipelines.

#### 4. Dual Execution Modes

- **Run mode:** Persistent workflows with configuration, context, dependencies, outputs
- **Task mode:** Lightweight one-off execution without workflow directories

Both modes share execution logic but optimized for different use cases.

**Innovation:** One tool handles both persistent iterative development and quick ad-hoc queries.

#### 5. Advanced Document Processing

- Automatic detection and processing of PDFs (32MB limit, ~2000 tokens/page)
- Office file conversion (.docx, .pptx) via LibreOffice with smart caching
- Vision API support for images (5MB limit, automatic resizing, base64 encoding)
- Text files with embedded metadata

**Innovation:** Unified handling of text, PDFs, Office files, and images with automatic format detection, conversion, caching, and optimal ordering.

#### 6. Prompt Caching Architecture

JSON-first content block architecture with strategic cache breakpoint placement (max 4) at semantic boundaries. Stable-to-volatile ordering: system prompts → project descriptions → PDFs → text → images → task. Date-only timestamps (not datetime) to prevent minute-by-minute cache invalidation.

**Innovation:** Sophisticated caching strategy that can achieve 90% cost reduction by carefully ordering content from most stable (system prompts) to most volatile (task), with PDFs placed before text per Anthropic optimization guidelines.

#### 7. Citations Support

Optional Anthropic citations API support via `--enable-citations` flag. Generates document map for citable sources (text and PDFs, not images). Parses citation responses and formats them appropriately. Creates sidecar citations files for reference.

**Innovation:** Enables source attribution for AI-generated content with proper citation tracking.

### Implementation Highlights

**JSON-First Architecture:**
- Content blocks are canonical JSON structures
- Pseudo-XML files created for debugging only (via custom converter)
- Eliminates dual-track complexity

**Safe Execution:**
- Automatic timestamped backups
- Hardlinked outputs for convenient access
- Atomic file operations
- Trap-based cleanup

**Token Estimation:**
- Dual approach: fast heuristic + exact API counting
- Detailed breakdowns by source (system, task, input, context, images)
- Conservative estimates (~2000 tokens/PDF page, ~1600 tokens/image)

### Technical Specifications

**Document Limits:**
- PDFs: 32MB per file, unlimited count
- Images: 5MB per file, 8000x8000px max, auto-resize at 1568px
- Office files: Converted to PDF (inherits PDF limits)
- Text files: No size limit

**API Integration:**
- Streaming mode: Real-time SSE parsing
- Batch mode: Single-request with pager
- Token Counting API: Exact token counts
- Citations API: Source attribution support

**Caching:**
- Up to 4 breakpoints per API limits
- 90% cost reduction potential
- 5-minute TTL (extendable to 1 hour)
- 1024 token minimum per cached block

### Target Audiences

**Researchers:** Literature review, paper analysis, synthesis across documents
**Developers:** Code analysis, documentation generation, technical writing
**Analysts:** Data interpretation, report generation, multi-source synthesis
**Writers:** Content creation with research context, structured output generation

---

## Version 0.1.0 (2025-11-18)

Initial pre-release version with core workflow management capabilities and configuration cascade system.

See CHANGELOG.md for detailed commit-level changes.
