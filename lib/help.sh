#!/usr/bin/env bash

# =============================================================================
# Workflow Help System
# =============================================================================
# Help text and usage documentation for workflow CLI tool.
# Provides main help and subcommand-specific help functions.
# This file is sourced by wireflow.sh.
# =============================================================================

SCRIPT_NAME="$(basename ${0})"

# =============================================================================
# Main Help
# =============================================================================

show_help() {
    cat <<EOF
Usage: $SCRIPT_NAME <subcommand> [options]

WireFlow - A CLI tool for building AI workflows anywhere
Version: $WIREFLOW_VERSION

Available subcommands:
    init [dir]       Initialize workflow project
    new NAME         Create new workflow
    edit [NAME]      Edit workflow or project files
    config [NAME]    View/edit configuration
    run NAME         Execute workflow with full context
    task NAME|TEXT   Execute one-off task (lightweight)
    cat NAME         Display workflow output
    open NAME        Open workflow output in default app (macOS)
    list, ls         List workflows in project
    tasks            Manage task templates
    help [CMD]       Show help for subcommand

Use 'wfw help <subcommand>' for detailed help on a specific command.
Use '$SCRIPT_NAME <subcommand> -h' for quick help.

Common options:
    -h, --help       Show help message
    -v, --version    Show version information

Examples:
    wfw init .
    wfw new 01-analysis
    wfw run 01-analysis --stream
    wfw task -i "Summarize findings" --context-file data.md

Environment variables:
    ANTHROPIC_API_KEY         Your Anthropic API key (required)
    WIREFLOW_PROMPT_PREFIX    System prompt directory (default: ~/.config/workflow/prompts)
    WIREFLOW_TASK_PREFIX      Named task directory (optional, for 'task' subcommand)

Configuration:
    Global config:   ~/.config/workflow/config
    Project config:  .workflow/config
    Workflow config: .workflow/<NAME>/config

For more information, see README.md or visit the documentation.
EOF
}

# =============================================================================
# Quick Help Functions (for -h flag)
# =============================================================================

show_quick_help_init() {
    echo "Usage: wfw init [<directory>]"
    echo "See 'wfw help init' for complete usage details."
}

show_quick_help_new() {
    echo "Usage: wfw new NAME [--task TEMPLATE]"
    echo "See 'wfw help new' for complete usage details."
}

show_quick_help_edit() {
    echo "Usage: wfw edit [<name>]"
    echo "See 'wfw help edit' for complete usage details."
}

show_quick_help_config() {
    echo "Usage: wfw config [<name>] [--edit]"
    echo "See 'wfw help config' for complete usage details."
}

show_quick_help_run() {
    echo "Usage: wfw run <name> [options]"
    echo "See 'wfw help run' for complete usage details."
}

show_quick_help_task() {
    echo "Usage: wfw task <name>|--inline <text> [options]"
    echo "See 'wfw help task' for complete usage details."
}

show_quick_help_tasks() {
    echo "Usage: wfw tasks [show|edit <name>]"
    echo "See 'wfw help tasks' for complete usage details."
}

show_quick_help_cat() {
    echo "Usage: wfw cat <name>"
    echo "See 'wfw help cat' for complete usage details."
}

show_quick_help_open() {
    echo "Usage: wfw open <name>"
    echo "See 'wfw help open' for complete usage details."
}

show_quick_help_list() {
    echo "Usage: wfw list"
    echo "See 'wfw help list' for complete usage details."
}

# =============================================================================
# Subcommand Help Functions (for 'workflow help <cmd>')
# =============================================================================

show_help_init() {
    cat <<EOF
Usage: wfw init [<directory>]

Initialize a workflow project with .workflow/ structure.

Arguments:
    <directory>    Directory to initialize (default: current directory)

Options:
    -h, --help     Quick help

Examples:
    wfw init .
    wfw init my-project
EOF
}

show_help_new() {
    cat <<EOF
Usage: wfw new <name> [options]

Create a new workflow in the current project.

Arguments:
    <name>         Workflow name (required)

Options:
    --task <template>  Use task template instead of default skeleton
    -h, --help         Quick help

Built-in Templates:
    Use 'workflow task ls' to see available templates

    summarize     Create concise summary with key points
    extract       Extract specific information and data
    analyze       Deep analysis of patterns and insights
    review        Critical evaluation with suggestions
    compare       Side-by-side comparison
    outline       Generate structured outline
    explain       Simplify complex topics
    critique      Identify problems and improvements

Examples:
    wfw new 01-outline
    wfw new paper-summary --task summarize
    wfw new data-analysis --task analyze

See Also:
    wfw task ls           # List all task templates
    wfw task show <name>  # Preview task template
EOF
}

show_help_edit() {
    cat <<EOF
Usage: wfw edit [<name>]

Edit workflow or project files in text editor.

Arguments:
    <name>         Workflow name (optional)

Options:
    -h, --help     Quick help

Behavior:
    Without <name>: Opens project files (project.txt, config)
    With <name>:    Opens workflow files (output, task.txt, config)

Examples:
    wfw edit
    wfw edit 01-outline
EOF
}

show_help_config() {
    cat <<EOF
Usage: wfw config [<name>] [options]

Display configuration with source tracking.

Arguments:
    <name>         Workflow name (optional)

Options:
    --edit         Prompt to edit configuration files
    -h, --help     Quick help

Examples:
    wfw config
    wfw config 01-analysis
EOF
}

show_help_run() {
    cat <<EOF
Usage: wfw run <name> [options]

Execute a workflow with full context aggregation.

Arguments:
    <name>         Workflow name (required)

Input Options (primary documents to analyze):
    --input-file <file>       Add input document (repeatable)
    --input-pattern <glob>    Add input files matching pattern

Context Options (supporting materials and references):
    --context-file <file>     Add context file (repeatable)
    --context-pattern <glob>  Add context files matching pattern
    --depends-on <workflow>   Include output from another workflow

API Options:
    --model <model>           Override model
    --temperature <temp>      Override temperature (0.0-1.0)
    --max-tokens <num>        Override max tokens
    --system-prompts <list>   Comma-separated prompt names
    --output-format <ext>     Output format (md, txt, json, etc.)
    --enable-citations        Enable Anthropic citations support
    --disable-citations       Disable citations (default)

Execution Options:
    --stream                  Stream output in real-time
    --count-tokens            Show token estimation only
    --dry-run                 Save API request files and inspect in editor
    -h, --help                Quick help

Examples:
    wfw run 01-analysis --stream
    wfw run 01-analysis --count-tokens
    wfw run 01-analysis --dry-run --count-tokens
EOF
}

show_help_task() {
    cat <<EOF
Usage: wfw task <name>|--inline <text> [options]

Execute a one-off task outside of existing workflows.

Task Specification:
    <name>                    Named task from \$WIREFLOW_TASK_PREFIX/<name>.txt
    -i, --inline <text>       Inline task specification

Input Options (primary documents to analyze):
    --input-file <file>       Add input document (repeatable)
    --input-pattern <glob>    Add input files matching pattern

Context Options (supporting materials and references):
    --context-file <file>     Add context file (repeatable)
    --context-pattern <glob>  Add context files matching pattern

API Options:
    --model <model>           Override model
    --temperature <temp>      Override temperature
    --max-tokens <num>        Override max tokens
    --system-prompts <list>   Comma-separated prompt names
    --output-format <ext>     Output format
    --enable-citations        Enable Anthropic citations support
    --disable-citations       Disable citations (default)

Output Options:
    --output-file <path>      Save to file (default: stdout)
    --stream                  Stream output (default: true)
    --no-stream               Use batch mode

Other Options:
    --count-tokens            Show token estimation only
    --dry-run                 Save API request files and inspect in editor
    -h, --help                Quick help

Examples:
    wfw task summarize --context-file paper.pdf
    wfw task -i "Summarize these notes" --context-file notes.md
    wfw task analyze --input-pattern "data/*.csv" --stream

See Also:
    wfw tasks           # List available task templates
    wfw tasks show <name>  # Preview template
    wfw new <name> --task <template>  # Create workflow from template
EOF
}

show_help_tasks() {
    cat <<EOF
Usage: wfw tasks [show|edit <name>]

Manage task templates.

Commands:
    tasks              List available task templates (default)
    tasks show <name>  Display task template in pager
    tasks edit <name>  Open task template in editor

Built-in Templates:
    summarize     Create concise summary with key points
    extract       Extract specific information and data
    analyze       Deep analysis of patterns and insights
    review        Critical evaluation with suggestions
    compare       Side-by-side comparison
    outline       Generate structured outline
    explain       Simplify complex topics
    critique      Identify problems and improvements

Task templates are stored in: \$WIREFLOW_TASK_PREFIX (default: ~/.config/workflow/tasks/)

Examples:
    wfw tasks
    wfw tasks show summarize
    wfw tasks edit summarize

See Also:
    wfw task <name>  # Execute task template
    wfw new <name> --task <template>  # Create workflow from template
EOF
}

show_help_cat() {
    cat <<EOF
Usage: wfw cat <name>

Display workflow output to stdout.

Arguments:
    <name>         Workflow name (required)

Options:
    -h, --help     Quick help

Examples:
    wfw cat 01-analysis
    wfw cat report | less
EOF
}

show_help_open() {
    cat <<EOF
Usage: wfw open <name>

Open workflow output in default application (macOS only).

Arguments:
    <name>         Workflow name (required)

Options:
    -h, --help     Quick help

Examples:
    wfw open report
    wfw open data-viz
EOF
}

show_help_list() {
    cat <<EOF
Usage: wfw list

List all workflows in the current project.

Options:
    -h, --help     Quick help

Alias: ls

Example:
    wfw list
EOF
}
