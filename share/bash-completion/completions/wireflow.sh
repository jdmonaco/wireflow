#!/usr/bin/env bash

# Bash completion for wireflow
# Source: https://github.com/jdmonaco/wireflow

_wireflow() {
    local cur prev words cword
    _init_completion || return

    # Main dispatch based on subcommand position
    if [[ $cword -eq 1 ]]; then
        _wireflow_subcommands
    else
        local subcommand="${words[1]}"
        case "$subcommand" in
            init)     _wireflow_init ;;
            new)      _wireflow_new ;;
            edit)     _wireflow_edit ;;
            config)   _wireflow_config ;;
            run)      _wireflow_run ;;
            task)     _wireflow_task ;;
            batch)    _wireflow_batch ;;
            tasks)    _wireflow_tasks ;;
            prompts)  _wireflow_prompts ;;
            cat)      _wireflow_cat ;;
            open)     _wireflow_open ;;
            list)     _wireflow_list ;;
            shell)    _wireflow_shell ;;
            help)     _wireflow_help ;;
            *)        return 0 ;;
        esac
    fi
}

# =============================================================================
# Subcommand Completions
# =============================================================================

_wireflow_subcommands() {
    local subcommands="init new edit config run task batch cat open tasks prompts list shell help"
    COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
}

# =============================================================================
# Helper Functions - Dynamic Listing
# =============================================================================

# Get list of workflows in current project
_wireflow_list_workflows() {
    local project_root
    project_root=$(wfw find-project-root 2>/dev/null) || return 1

    local run_dir="$project_root/.workflow/run"
    [[ ! -d "$run_dir" ]] && return 1

    # List workflow directories
    find "$run_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
}

# Helper: List tasks from a directory with subdirectory support
_wireflow_list_tasks_from_dir() {
    local dir="$1"
    [[ ! -d "$dir" ]] && return

    # Find .txt files up to 3 levels deep, output relative paths without .txt
    find "$dir" -maxdepth 3 -name "*.txt" -type f 2>/dev/null | while read -r file; do
        local relpath="${file#$dir/}"
        echo "${relpath%.txt}"
    done
}

# Get list of available tasks (with subdirectory support)
# Lists custom location first, then builtins
_wireflow_list_tasks() {
    local builtin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wireflow/prompts/tasks"
    local custom_dir="${WIREFLOW_TASK_PREFIX:-}"

    # List from custom location first (if set and different from builtin)
    if [[ -n "$custom_dir" && -d "$custom_dir" && "$custom_dir" != "$builtin_dir" ]]; then
        _wireflow_list_tasks_from_dir "$custom_dir"
    fi

    # List from builtin location
    _wireflow_list_tasks_from_dir "$builtin_dir"
}

# Helper: List prompts from a directory with subdirectory support
_wireflow_list_prompts_from_dir() {
    local dir="$1"
    [[ ! -d "$dir" ]] && return

    # Find .txt files up to 3 levels deep, output relative paths without .txt
    find "$dir" -maxdepth 3 -name "*.txt" -type f 2>/dev/null | while read -r file; do
        local relpath="${file#$dir/}"
        echo "${relpath%.txt}"
    done
}

# Get list of available prompts (with subdirectory support)
# Lists custom location first, then builtins
# Filters out 'meta' since it's auto-included
_wireflow_list_prompts() {
    local builtin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wireflow/prompts/system"
    local custom_dir="${WIREFLOW_PROMPT_PREFIX:-}"

    {
        # List from custom location first (if set and different from builtin)
        if [[ -n "$custom_dir" && -d "$custom_dir" && "$custom_dir" != "$builtin_dir" ]]; then
            _wireflow_list_prompts_from_dir "$custom_dir"
        fi

        # List from builtin location
        _wireflow_list_prompts_from_dir "$builtin_dir"
    } | grep -v '^meta$'
}

# Common API options
_wireflow_api_options() {
    echo "--model -m --profile --temperature -t --max-tokens"
    echo "--system -p --format -f"
    echo "--enable-thinking --disable-thinking --thinking-budget --effort"
    echo "--enable-citations --disable-citations --provider"
}

# Common input/context options
_wireflow_input_options() {
    echo "--input -in --context -cx"
}

# Run-mode execution options (streaming is opt-in, no --no-stream)
_wireflow_run_execution_options() {
    echo "--stream -s --count-tokens --dry-run -n"
}

# Task-mode execution options (streaming is default, --no-stream available)
_wireflow_task_execution_options() {
    echo "--stream -s --no-stream --count-tokens --dry-run -n"
}

# Batch-mode execution options (no streaming at all)
_wireflow_batch_execution_options() {
    echo "--count-tokens --dry-run -n"
}

# Run-specific options
_wireflow_run_options() {
    echo "--depends-on -dp --export -ex --no-auto-deps"
}

# Check if we're in a multi-value option context (-cx, -in, -dp)
_wireflow_in_multi_value_context() {
    local i
    for ((i=cword-1; i>=2; i--)); do
        local word="${words[i]}"
        # If we hit an option, check if it's a multi-value one
        [[ "$word" == -* ]] && {
            case "$word" in
                --context|-cx|--input|-in|--depends-on|-dp|--system|-p)
                    return 0  # Yes, in multi-value context
                    ;;
                *)
                    return 1  # Hit a different option
                    ;;
            esac
        }
    done
    return 1
}

# Find which multi-value option started the current context
_wireflow_get_multi_value_option() {
    local i
    for ((i=cword-1; i>=2; i--)); do
        case "${words[i]}" in
            --context|-cx|--input|-in)
                echo "file"
                return 0
                ;;
            --depends-on|-dp)
                echo "workflow"
                return 0
                ;;
            --system|-p)
                echo "prompt"
                return 0
                ;;
        esac
        [[ "${words[i]}" == -* ]] && break
    done
    return 1
}

# Check if we're after a '--' separator (input paths only, no options)
_wireflow_after_double_dash() {
    local i
    for ((i=1; i<cword; i++)); do
        [[ "${words[i]}" == "--" ]] && return 0
    done
    return 1
}

# =============================================================================
# Subcommand-Specific Completions
# =============================================================================

_wireflow_init() {
    case "$prev" in
        init)
            # Complete directory paths
            _filedir -d
            ;;
        *)
            # No other options
            return 0
            ;;
    esac
}

_wireflow_new() {
    case "$prev" in
        --from-task)
            # Complete with task names
            COMPREPLY=($(compgen -W "$(_wireflow_list_tasks)" -- "$cur"))
            ;;
        new)
            # First arg is workflow name (no completion)
            return 0
            ;;
        *)
            # Complete options
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--from-task --help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_edit() {
    case "$prev" in
        edit)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_config() {
    case "$prev" in
        config)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--edit --help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_run() {
    # Early return for paths after --
    if _wireflow_after_double_dash; then
        _filedir
        return 0
    fi

    local workflow_specified=false
    local i

    # Check if workflow name has been specified
    for ((i=2; i<cword; i++)); do
        if [[ "${words[i]}" != -* ]]; then
            # Check it's not a value for a single-value option
            local prev_word="${words[i-1]}"
            case "$prev_word" in
                --model|-m|--profile|--temperature|-t|--max-tokens|--system|-p|--format|-f|--effort|--thinking-budget|--export|-ex)
                    continue
                    ;;
            esac
            workflow_specified=true
            break
        fi
    done

    if ! $workflow_specified; then
        # First arg: complete workflow names
        if [[ "$cur" == -* ]]; then
            local opts="$(_wireflow_api_options) $(_wireflow_input_options) $(_wireflow_run_execution_options) $(_wireflow_run_options)"
            opts="$opts --help -h"
            COMPREPLY=($(compgen -W "$opts" -- "$cur"))
        else
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
        fi
        return 0
    fi

    # Handle multi-value options (-cx, -in, -dp, -p)
    if [[ "$cur" != -* ]]; then
        case "$prev" in
            --context|-cx|--input|-in)
                _filedir
                return 0
                ;;
            --depends-on|-dp)
                COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
                return 0
                ;;
            --system|-p)
                COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
                return 0
                ;;
        esac

        # Check if we're continuing a multi-value sequence
        if _wireflow_in_multi_value_context; then
            local context_type
            context_type=$(_wireflow_get_multi_value_option)
            case "$context_type" in
                file)
                    _filedir
                    return 0
                    ;;
                workflow)
                    COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
                    return 0
                    ;;
                prompt)
                    COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
                    return 0
                    ;;
            esac
        fi
    fi

    # After workflow name: complete options
    case "$prev" in
        --model|-m)
            COMPREPLY=($(compgen -W "claude-opus-4-5 claude-sonnet-4-5 claude-haiku-4-5" -- "$cur"))
            ;;
        --profile)
            COMPREPLY=($(compgen -W "fast balanced deep" -- "$cur"))
            ;;
        --temperature|-t)
            COMPREPLY=($(compgen -W "0.0 0.3 0.5 0.7 1.0" -- "$cur"))
            ;;
        --max-tokens)
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384" -- "$cur"))
            ;;
        --thinking-budget)
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384 32768" -- "$cur"))
            ;;
        --effort)
            COMPREPLY=($(compgen -W "low medium high" -- "$cur"))
            ;;
        --provider)
            COMPREPLY=($(compgen -W "anthropic openai" -- "$cur"))
            ;;
        --system|-p)
            COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
            ;;
        --format|-f)
            COMPREPLY=($(compgen -W "md txt json html xml" -- "$cur"))
            ;;
        --export|-ex)
            _filedir
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                local opts="$(_wireflow_api_options) $(_wireflow_input_options) $(_wireflow_run_execution_options) $(_wireflow_run_options)"
                opts="$opts --help -h"
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_task() {
    # Early return for paths after --
    if _wireflow_after_double_dash; then
        _filedir
        return 0
    fi

    local task_specified=false
    local i

    # Check if task name or --inline has been specified
    for ((i=2; i<cword; i++)); do
        if [[ "${words[i]}" == "--inline" || "${words[i]}" == "-i" ]]; then
            task_specified=true
            break
        elif [[ "${words[i]}" != -* ]]; then
            # Check it's not a value for a single-value option
            local prev_word="${words[i-1]}"
            case "$prev_word" in
                --model|-m|--profile|--temperature|-t|--max-tokens|--system|-p|--format|-f|--effort|--thinking-budget|--export|-ex)
                    continue
                    ;;
            esac
            task_specified=true
            break
        fi
    done

    if ! $task_specified; then
        # First arg: complete task names or --inline
        if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "--inline -i --help -h" -- "$cur"))
        else
            COMPREPLY=($(compgen -W "$(_wireflow_list_tasks)" -- "$cur"))
        fi
        return 0
    fi

    # Handle multi-value options (-cx, -in, -p)
    if [[ "$cur" != -* ]]; then
        case "$prev" in
            --context|-cx|--input|-in)
                _filedir
                return 0
                ;;
            --system|-p)
                COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
                return 0
                ;;
        esac

        # Check if we're continuing a multi-value sequence
        if _wireflow_in_multi_value_context; then
            local context_type
            context_type=$(_wireflow_get_multi_value_option)
            case "$context_type" in
                file)
                    _filedir
                    return 0
                    ;;
                prompt)
                    COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
                    return 0
                    ;;
            esac
        fi
    fi

    # After task name: complete options (same as run, minus --depends-on)
    case "$prev" in
        --inline|-i)
            # No completion for inline text
            return 0
            ;;
        --model|-m)
            COMPREPLY=($(compgen -W "claude-opus-4-5 claude-sonnet-4-5 claude-haiku-4-5" -- "$cur"))
            ;;
        --profile)
            COMPREPLY=($(compgen -W "fast balanced deep" -- "$cur"))
            ;;
        --provider)
            COMPREPLY=($(compgen -W "anthropic openai" -- "$cur"))
            ;;
        --temperature|-t)
            COMPREPLY=($(compgen -W "0.0 0.3 0.5 0.7 1.0" -- "$cur"))
            ;;
        --max-tokens)
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384" -- "$cur"))
            ;;
        --thinking-budget)
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384 32768" -- "$cur"))
            ;;
        --effort)
            COMPREPLY=($(compgen -W "low medium high" -- "$cur"))
            ;;
        --system|-p)
            COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
            ;;
        --format|-f)
            COMPREPLY=($(compgen -W "md txt json html xml" -- "$cur"))
            ;;
        --export|-ex)
            _filedir
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                local opts="$(_wireflow_api_options) $(_wireflow_input_options) $(_wireflow_task_execution_options)"
                opts="$opts --export -ex --help -h"
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_batch() {
    # Early return for paths after --
    if _wireflow_after_double_dash; then
        _filedir
        return 0
    fi

    local batch_subcmd=""
    local workflow_specified=false
    local i

    # Check for batch subcommand or workflow name
    for ((i=2; i<cword; i++)); do
        case "${words[i]}" in
            status|results|cancel)
                batch_subcmd="${words[i]}"
                break
                ;;
        esac
        if [[ "${words[i]}" != -* ]]; then
            # Check it's not a value for a single-value option
            local prev_word="${words[i-1]}"
            case "$prev_word" in
                --model|-m|--profile|--temperature|-t|--max-tokens|--system|-p|--format|-f|--effort|--thinking-budget|--export|-ex)
                    continue
                    ;;
            esac
            workflow_specified=true
            break
        fi
    done

    case "$prev" in
        batch)
            # First arg: subcommand or workflow name
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "status results cancel $(_wireflow_list_workflows)" -- "$cur"))
            fi
            return 0
            ;;
        status|results|cancel)
            # After subcommand: workflow name
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            return 0
            ;;
    esac

    # If batch subcommand was specified, no more completions needed
    [[ -n "$batch_subcmd" ]] && return 0

    # Handle multi-value options for batch submit (-cx, -in, -dp, -p)
    if [[ "$cur" != -* ]]; then
        case "$prev" in
            --context|-cx|--input|-in)
                _filedir
                return 0
                ;;
            --depends-on|-dp)
                COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
                return 0
                ;;
            --system|-p)
                COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
                return 0
                ;;
        esac

        if _wireflow_in_multi_value_context; then
            local context_type
            context_type=$(_wireflow_get_multi_value_option)
            case "$context_type" in
                file)
                    _filedir
                    return 0
                    ;;
                workflow)
                    COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
                    return 0
                    ;;
                prompt)
                    COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
                    return 0
                    ;;
            esac
        fi
    fi

    # Options for batch submit (similar to run)
    case "$prev" in
        --model|-m)
            COMPREPLY=($(compgen -W "claude-opus-4-5 claude-sonnet-4-5 claude-haiku-4-5" -- "$cur"))
            ;;
        --profile)
            COMPREPLY=($(compgen -W "fast balanced deep" -- "$cur"))
            ;;
        --temperature|-t)
            COMPREPLY=($(compgen -W "0.0 0.3 0.5 0.7 1.0" -- "$cur"))
            ;;
        --max-tokens)
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384" -- "$cur"))
            ;;
        --thinking-budget)
            COMPREPLY=($(compgen -W "1024 2048 4096 8192 16384 32768" -- "$cur"))
            ;;
        --effort)
            COMPREPLY=($(compgen -W "low medium high" -- "$cur"))
            ;;
        --system|-p)
            COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
            ;;
        --format|-f)
            COMPREPLY=($(compgen -W "md txt json html xml" -- "$cur"))
            ;;
        --export|-ex)
            _filedir
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                local opts="$(_wireflow_api_options) $(_wireflow_input_options) $(_wireflow_batch_execution_options) $(_wireflow_run_options)"
                opts="$opts --help -h"
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_tasks() {
    case "$prev" in
        tasks)
            # Complete with subcommands or task names
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "list show edit" -- "$cur"))
            fi
            ;;
        show|edit)
            # Complete with task names
            COMPREPLY=($(compgen -W "$(_wireflow_list_tasks)" -- "$cur"))
            ;;
        list)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
        *)
            return 0
            ;;
    esac
}

_wireflow_prompts() {
    case "$prev" in
        prompts)
            # Complete with subcommands or prompt names
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "list show edit" -- "$cur"))
            fi
            ;;
        show|edit)
            # Complete with prompt names
            COMPREPLY=($(compgen -W "$(_wireflow_list_prompts)" -- "$cur"))
            ;;
        list)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
        *)
            return 0
            ;;
    esac
}

_wireflow_cat() {
    case "$prev" in
        cat)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_open() {
    case "$prev" in
        open)
            # Complete with workflow names
            COMPREPLY=($(compgen -W "$(_wireflow_list_workflows)" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_list() {
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
    fi
}

_wireflow_shell() {
    case "$prev" in
        shell)
            COMPREPLY=($(compgen -W "install doctor uninstall" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
            fi
            ;;
    esac
}

_wireflow_help() {
    case "$prev" in
        help)
            # Complete with subcommand names
            COMPREPLY=($(compgen -W "init new edit config run task batch tasks cat open list shell" -- "$cur"))
            ;;
    esac
}

# Register completion function
complete -F _wireflow wfw wireflow
