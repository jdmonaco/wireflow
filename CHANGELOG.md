# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.3] - 2025-12-04

### Added
- `wfw prompts` subcommand for system prompt management (0587543)
- `wfw models` subcommand for provider settings and available models (52dd653)
- `wfw models ps` for running/loaded models on local servers (d9bf987)
- Ollama server detection via port :11434 with rich API support (d9bf987)
- Model validation before expensive operations (a1bb9a3)
- Excel (.xlsx) support via LibreOffice PDF conversion (2d201a7)
- External image embeds via Markdown `![alt](url)` syntax (041a185)
- Cache status indicators for image processing messages (9dd0a8d)
- `--provider` CLI option for run/task modes (8e43aed)
- Terminal output warning for unsaved task mode output (aca0339)
- Multi-argument `--system/-p` option pattern (5ae30bc)
- Enhanced backup organization in timestamped subdirectories (5e174c5)

### Changed
- **BREAKING:** `--system/-p` uses multi-argument pattern instead of comma-separated (5ae30bc)
- **BREAKING:** `OPENAI_BASE_URL` no longer includes /v1 suffix (415a3c2)
- Project-relative paths in console output via display_path() (bbae358)
- JSON-to-XML conversion uses yq instead of complex jq script (94d72a3)
- Pager display moved to end of run/task mode (cd1ba7a)

### Fixed
- Cache status detection for remote images without resize (bda9a4b)
- mktemp template suffix for macOS compatibility (253a045)
- Ollama status checks use /api/tags endpoint (6087a3f)
- OpenAI provider config loading from project config (415a3c2)
- execution.json path bug with $project_root variable (49b7531)
- Duplicate system prompts in dependency resolution (065b5dc)
- jq "Argument list too long" via --slurpfile (065b5dc)
- Task mode PDF processing and system prompt ordering (997b7bf)
- OpenAI document blocks use text type instead of document (2d201a7)

## [0.7.2] - 2025-12-02

### Added
- Full nested project path display in `__wfw_ps1` prompt function (b641032)
- Ancestor project discovery helper `__wfw_find_ancestor_projects()` in wfw-prompt.sh

### Changed
- Bash completion overhauled for current CLI options (e8cd517)
- Task template completion discovers subdirectories up to 3 levels deep
- Mode-specific execution options (run/task/batch have separate option sets)
- Custom task templates listed before builtins in completion
- Key Features documentation updated for accuracy (c1d36ed)

### Fixed
- Shell doctor now detects `__wfw_ps1` by checking function definition instead of PS1 string (8a1d128)
- Dry-run output simplified with accurate config source tracking (2350436)
- Removed stale `--force` and `-b` options from bash completion

## [0.7.1] - 2025-12-01

### Added
- Streaming markdown renderer for terminal output using rich library (b82b2a0)
- New `lib/output.sh` module with FIFO-based renderer lifecycle management
- `bin/md-render` Python script with uv auto-dependency management (PEP 723)
- Unit tests for output.sh renderer functions

### Changed
- Streaming console output now displays formatted markdown in terminal mode
- Piped/redirected output passes through raw markdown unchanged
- Extended thinking blocks bypass renderer, keep ANSI dim formatting

## [0.7.0] - 2025-12-01

### Added
- OpenAI-compatible API provider support for local LLM servers (LM Studio, ollama, vLLM)
- New `lib/openai.sh` library with streaming and non-streaming API handlers
- Provider selection via `PROVIDER` config variable (`anthropic` or `openai`)
- OpenAI model profiles: `OPENAI_MODEL_FAST`, `OPENAI_MODEL_BALANCED`, `OPENAI_MODEL_DEEP`
- PDF-to-image conversion for OpenAI provider using `pdftoppm` (poppler-utils)
- `convert_pdf_to_images()` function with caching in `lib/utils.sh`
- Provider dispatch in `execute_api_request()` with feature compatibility warnings
- Unit tests for OpenAI provider functions (`tests/unit/openai.bats`)
- Integration tests for provider configuration (`tests/integration/openai.bats`)
- Provider documentation in installation guide and configuration reference

### Changed
- Updated README.md and docs/index.md with Multi-Provider key feature
- Updated help text to show provider settings
- Installation guide now covers both Anthropic and OpenAI-compatible setups

## [0.6.0] - 2025-11-29

### Added
- Shell integration with `wfw shell` subcommand: install, doctor, uninstall (32759ba, c0a49d6)
- PS1 prompt integration via `__wfw_ps1()` function (1801cd7)
- Obsidian markdown embed preprocessing: `![[file]]` syntax support (d3d1ccb)
- Automatic dependency execution with execution caching (a51eeb1)
- Multi-argument support for `--input`/`-in` and `--context`/`-cx` options (ee9e146)
- Shell integration commands in installation guide (25dfa1a)
- Pipeline module for dependency resolution and execution caching (a51eeb1)

### Changed
- Consolidated CONTEXT/INPUT config into single arrays for cleaner handling (e179184)
- Reorganized reference and developer-guide documentation (ec75d6d, 8cab58f)
- Updated user-guide for accuracy and formatting (c769c3c)
- Documentation list separators enforced for mkdocs compatibility (e0702f6, e6031d7, f12aebc)
- Pipeline and syntax documentation updates (b5d35ae)

### Fixed
- XML completion for builtin task templates (7d6950e)
- Added doctor and uninstall to shell completions (e072ef6)

## [0.5.0] - 2025-11-28

### Added
- Message Batches API support with `wfw batch` subcommand for 50% cost savings (f681121)
- Model profiles: `fast`, `balanced`, `deep` with `--profile` flag (365a7dc)
- Extended thinking support with `THINKING_BUDGET` parameter (365a7dc)
- Effort parameter support for Claude Opus 4.5 (`EFFORT=high`) (365a7dc)
- Simplified CLI input/context flags: `-in` and `-cx` shorthand (357286a)
- Project-level shared cache for file conversions with hash-based IDs (20f29e0)
- Image format conversion: HEIC/HEIF → JPEG, TIFF/TIF → PNG, SVG → PNG (6618f58)
- macOS `sips` fallback for HEIC conversion when ImageMagick lacks libheif (6618f58)

### Changed
- Batch commands consolidated under `wfw batch` subcommand (c34081d)
- Batch API removed from task mode (workflow-only feature) (3b9c827)
- Reference docs updated to use "WireFlow" consistently (6618f58)
- Key Features updated in README.md and docs/index.md

## [0.4.0] - 2025-11-25

### Added
- Test runner script `tests/run-tests.sh` with unit/integration/all/quick commands (6686886)
- Unit test files for each lib/*.sh module: api, config, core, edit, execute, help, utils (6686886)
- Integration test files for each CLI command: cat, config, help, init, list, new, run, task (6686886)
- Enhanced test helpers: mock_env.sh, fixtures.sh, assertions.sh (6686886)
- Bash completion script `share/bash-completion.bash` (b2bde30)
- OUTPUT_FILE workflow configuration parameter (33189fc)
- lib/run.sh module for run mode execution (f4afcfb)

### Changed
- Migrated test suite from flat structure (280+ tests) to unit/integration architecture (~137 tests) (6686886)
- Streamlined Key Features in README.md and docs/index.md with punchier descriptions (6937f0a)
- Updated CLI help text with concise descriptions and `--long, -s` option formatting (45ff128)
- Refreshed all documentation for recent refactors (8dacf5a)
- Fixed workflow paths to use `.workflow/run/<name>/` consistently
- Updated contributing guides for new test structure
- Refactored lib/core.sh with function fixes and naming improvements (d05cf0a)
- Refactored wireflow.sh with bug fixes (51774fe)

### Fixed
- Circular dependency handling in lib/execute.sh (43328e9)
- Config cascade behavior in lib/config.sh (fb911ce)
- Task mode execution and critical fixes in lib/task.sh (696cff7)
- API error handling in lib/api.sh (9a2dd46)
- Path resolution and utility enhancements in lib/utils.sh (293857d)
- Task subcommand description display and fallback (6a977a5)
- Editor detection in lib/edit.sh (d6527cd)
- Help documentation and path fixes in lib/help.sh (0a62bca)
- Test failures after renaming (01f5087, 38f3ac8, d29b649)
- Remaining workflow to wireflow renaming issues (bbfce00, e9fc82c)

## [0.3.0] - 2025-11-20

### Added
- Built-in task templates system with 8 generic reusable templates (f6da1b2, ebde182, 93af20c)
- `wfw tasks` subcommand for managing task templates (list, show, edit)
- `wfw new --task <template>` flag to create workflows from templates
- Fallback search for prompts and tasks to preserve built-ins when using custom PREFIX (97827f7)
- Meta system prompt for automatic workflow context orientation (0ed05c1)
- Adaptive cache-control strategy respecting 4-breakpoint API limit (f6da1b2)

### Changed
- **BREAKING:** Renamed project from Workflow to WireFlow (81223c4)
- **BREAKING:** Environment variables: WORKFLOW_*_PREFIX → WIREFLOW_*_PREFIX
- **BREAKING:** Script name: workflow.sh → wireflow.sh
- **BREAKING:** Command name: workflow → wireflow (alias wfw recommended)
- Refactored CLAUDE.md into 3 focused files (74% size reduction) (0c8174a)
- Reorganized contributing docs under docs/contributing/ (534aed0)
- Updated Key Features to reflect v0.2.0 capabilities accurately (7d95bc3)
- Reordered User Guide in docs (Configuration before Creating Workflows)
- Enabled WIREFLOW_TASK_PREFIX by default in global config

### Fixed
- Cache-control strategy now adaptive based on content mix (PDFs/text/images)
- Images now properly receive cache_control (was missing entirely)
- Total breakpoints never exceed 4 (was exceeding with per-section strategy)

## [Unreleased]

## [0.2.0] - 2025-01-20

### Added
- PDF document support via Claude API (32MB limit, joint text+visual analysis)
- Microsoft Office file support (.docx, .pptx auto-conversion via LibreOffice)
- Image processing with Vision API (automatic resizing, 5MB limit)
- Citations API support with document index mapping
- JSON-first content block architecture
- Prompt caching with strategic breakpoint placement
- Nested project descriptions aggregation
- Comprehensive document processing guides

### Changed
- Content blocks now use JSON-first architecture (XML files for debugging only)
- PDF documents positioned before text for optimal processing
- System prompt composition includes project descriptions
- Date format changed to date-only (prevents minute-by-minute cache invalidation)
- Enhanced token estimation with image token calculations

### Fixed
- Path resolution for nested projects
- Office file caching with mtime validation
- Image resizing for Vision API compliance

## [0.1.0] - 2025-11-18

### Added
- Initial pre-release version
- Core workflow management subcommands:
  - `init` - Initialize workflow project structure
  - `new` - Create new workflows with XML task skeleton
  - `edit` - Edit workflow or project files
  - `config` - View and manage configuration cascade
  - `run` - Execute workflows with full context aggregation
  - `task` - Lightweight one-off task execution
  - `cat` - Display workflow output to stdout
  - `open` - Open workflow output in default app (macOS)
  - `list` - List workflows in project
- Task.txt XML skeleton with structured sections:
  - `<description>` - Brief workflow overview
  - `<guidance>` - Strategic approach
  - `<instructions>` - Detailed requirements
  - `<output-format>` - Format specifications
- Configuration cascade system (global → ancestors → project → workflow → CLI)
- Nested project support with config and description inheritance
- Context aggregation from multiple sources:
  - Glob patterns (CONTEXT_PATTERN)
  - Explicit file lists (CONTEXT_FILES)
  - Workflow dependencies (DEPENDS_ON)
  - CLI options (--context-file, --context-pattern)
- Streaming and batch API modes
- Token estimation (--count-tokens)
- Dry-run mode for prompt inspection (--dry-run)
- Cross-platform editor selection (respects VISUAL/EDITOR)
- Refactored execution logic in lib/execute.sh
- Comprehensive test suite (208 tests)
- MkDocs documentation structure
- Version display via --version flag
- CHANGELOG for tracking changes

### Technical Details
- Modular architecture with lib/ directory structure
- Safe execution with backups, atomic writes, cleanup traps
- Git-like project discovery (walks directory tree)
- Hardlinks for output file management
- Pass-through inheritance in configuration cascade
