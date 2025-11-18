# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
