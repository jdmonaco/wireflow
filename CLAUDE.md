# WireFlow - Development Guide

Quick reference for development workflows and processes.

**For user documentation, see `docs/` directory and README.md.**

## Developer Documentation Index

- **[docs/developer-guide/index.md](docs/developer-guide/index.md)**: Getting started, development setup, commit guidelines
- **[docs/developer-guide/architecture.md](docs/developer-guide/architecture.md)**: System design, architecture patterns, design decisions
- **[docs/developer-guide/implementation.md](docs/developer-guide/implementation.md)**: Module reference, implementation details, technical gotchas

## Testing

**Framework:** Bats (Bash Automated Testing System)

```bash
# Using test runner (RECOMMENDED)
./tests/run-tests.sh unit              # Run all unit tests
./tests/run-tests.sh integration       # Run all integration tests
./tests/run-tests.sh all               # Run all tests (~137 tests)
./tests/run-tests.sh quick             # Unit tests in parallel

# Direct bats invocation
bats tests/unit/config.bats            # Specific unit test
bats tests/integration/run.bats        # Specific integration test
```

**Structure:** `tests/unit/` (one file per lib/*.sh) + `tests/integration/` (one file per CLI command)

**Details:** See [docs/developer-guide/implementation.md#testing-implementation](docs/developer-guide/implementation.md#testing-implementation)

## Documentation Updates

When making interface changes:

1. Code implementation and tests
2. `lib/help.sh`: CLI help text
3. `docs/`: User-facing documentation
4. README.md and docs/index.md: Keep synchronized (Key Features must match)
5. Verify with `mkdocs serve` (activate venv first: `source venv/bin/activate`)

**Hierarchy:**

```
README.md               → Brief overview, links to docs
docs/index.md           → Landing page (must sync with README.md)
docs/getting-started/   → Installation, tutorials
docs/user-guide/        → Complete usage guide
docs/reference/         → CLI command reference (per-command pages)
lib/help.sh             → CLI help text
docs/developer-guide/   → Architecture, implementation, layer docs
```

### Style Guidelines

**Key Features (README.md and docs/index.md):**
```markdown
- 🎯 **Feature Name:** Punchy one-liner description.
```

**CLI help option formatting:**
```
--long-option, -s <arg>   Description text
```

**Nested bullets:** Use 4 spaces (not 2)

**Lists after text:** Add blank line before lists (required for mkdocs rendering)

**Subcommand ordering:** init → new → edit → config → run → task → cat → open → tasks → list → help

## Development Workflows

### Adding a Subcommand

1. Add case to `wireflow.sh` subcommand dispatcher
2. Implement in `lib/core.sh` (or new lib file if complex)
3. Add help function to `lib/help.sh`
4. Add `-h` check to subcommand case
5. Add integration test: `tests/integration/<subcommand>.bats`
6. Add unit tests: `tests/unit/<lib>.bats`
7. Document in `docs/reference/<subcommand>.md` (per-command page)

### Modifying Configuration

1. Update loading logic in `lib/config.sh`
2. Update display in `show_config()` in `lib/core.sh`
3. Document in `docs/user-guide/configuration.md`
4. Add tests in `tests/unit/config.bats` and `tests/integration/config.bats`

### Changing API Interaction

1. Modify `lib/api.sh`
2. Test both streaming and batch modes
3. Update token estimation if request structure changes

## Coding Conventions

### Boolean Variables

Global execution-mode flags use string values `"true"`/`"false"`. Always compare with quoted strings:

```bash
# Correct
if [[ "$DRY_RUN" == "true" ]]; then
if [[ "$COUNT_TOKENS" != "true" ]]; then
if [[ "$STREAM_MODE" == "true" ]] && [[ "$ENABLE_THINKING" != "true" ]]; then

# Incorrect - avoid unquoted or -eq comparisons
if [[ $DRY_RUN ]]; then           # Wrong: tests if variable is set, not value
if [[ "$DRY_RUN" -eq 1 ]]; then   # Wrong: these are strings, not integers
```

Common boolean globals: `DRY_RUN`, `COUNT_TOKENS`, `STREAM_MODE`, `ENABLE_THINKING`, `ENABLE_CITATIONS`

### Option Parsing (parse_common_option)

When adding options to `parse_common_option()` in `lib/execute.sh`:

```bash
# Value option (PARSE_CONSUMED=2)
--my-option)
    [[ $# -eq 0 ]] && { echo "Error: --my-option requires argument" >&2; return 1; }
    MY_OPTION="$1"
    CONFIG_SOURCE_MAP[MY_OPTION]="cli"
    PARSE_CONSUMED=2
    ;;

# Flag option (PARSE_CONSUMED=1)
--my-flag)
    MY_FLAG="true"
    CONFIG_SOURCE_MAP[MY_FLAG]="cli"
    PARSE_CONSUMED=1
    ;;
```

Note: Do NOT add `shift` inside the case - the function already shifts after storing `$1` in `opt`.

### Dependency Resolution

Use `collect_all_dependencies()` for resolving component dependencies (system prompts or tasks). It uses nameref to avoid subshell variable loss:

```bash
local -A TRACKER=()
mapfile -t components < <(collect_all_dependencies \
    "TRACKER" \
    "WIREFLOW_PROMPT_PREFIX" \
    "BUILTIN_WIREFLOW_PROMPT_PREFIX" \
    "${ROOT_COMPONENTS[@]}")
```

### Large JSON Payloads

Use `--slurpfile` instead of `--argjson` to avoid "Argument list too long" errors:

```bash
# Correct - reads from file
jq -n --slurpfile data "$temp_file" '{ content: $data[0] }'

# Incorrect - passes via command line (subject to ARG_MAX)
jq -n --argjson data "$large_json" '{ content: $data }'
```

## Version Management

**Current version:** 0.6.0 (pre-release)

**Location:** `WIREFLOW_VERSION` in `wireflow.sh` (line 14)

**Version files to update:**
- `wireflow.sh` (line 14)
- `README.md` (line 5)
- `docs/index.md` (line 5)

### Release Process

1. **Update RELEASE-NOTES.md** - Add version section with narrative
2. **Update CHANGELOG.md** - Add version with Added/Changed/Fixed sections and commit refs
3. **Bump version** in wireflow.sh, README.md, docs/index.md
4. **Commit:** `chore: Release version X.Y.Z`
5. **Tag:** `git tag -a vX.Y.Z -m "Release version X.Y.Z ..."`
6. **Verify:** `wfw --version`, `git show vX.Y.Z --no-patch`
7. **Push:** `git push origin main --tags`

### Semantic Versioning

- **0.x.x:** Pre-release (API may change)
- **MAJOR:** Breaking CLI/config changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes

## Git Workflow

**Commit format:**
```
<type>: <subject>

<body>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:** feat, fix, docs, test, refactor, style, chore

**Subject:** Max 72 chars, imperative mood
