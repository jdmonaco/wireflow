#!/usr/bin/env bash
# =============================================================================
# WireFlow PS1 Prompt Integration
# =============================================================================
# Provides __wfw_ps1() for including project name in shell prompt.
#
# Usage:
#   source ~/.local/share/wireflow/wfw-prompt.sh
#   export PS1='\w$(__wfw_ps1 " (%s)")\$ '
#
# The optional format argument defaults to " (%s)" where %s is replaced
# with the wireflow project path. For nested projects, this shows the full
# ancestor path (e.g., "root/parent/project" instead of just "project").
# =============================================================================

# Find WireFlow project root by walking up the directory tree
# Returns the project root path, or exits with status 1 if not in a project
__wfw_find_project_root() {
    local dir="${1:-$PWD}"
    local max_depth=100
    local depth=0

    # Get canonical path
    if [[ -d "$dir" ]]; then
        dir="$(cd "$dir" 2>/dev/null && pwd -P)" || dir="${1:-$PWD}"
    fi
    [[ -z "$dir" ]] && return 1

    while [[ "$dir" != "/" && $depth -lt $max_depth ]]; do
        if [[ -d "$dir/.workflow" ]]; then
            echo "$dir"
            return 0
        fi
        local parent
        parent="$(dirname "$dir")"
        [[ "$parent" == "$dir" ]] && break
        dir="$parent"
        ((depth++))
    done

    [[ -d "/.workflow" ]] && echo "/" && return 0
    return 1
}

# Find ancestor WireFlow projects above the given project root
# Outputs ancestor paths from oldest (highest level) to newest (closest)
__wfw_find_ancestor_projects() {
    local project_root="$1"
    local dir="$(dirname "$project_root")"
    local -a roots=()

    while [[ "$dir" != "/" ]]; do
        [[ -d "$dir/.workflow" ]] && roots+=("$dir")
        dir="$(dirname "$dir")"
    done

    # Print in reverse (oldest ancestor first)
    for ((i=${#roots[@]}-1; i>=0; i--)); do
        printf '%s\n' "${roots[i]}"
    done
}

# Print formatted project path for PS1 prompt integration
# Usage: __wfw_ps1 [format]
#   format: printf format string (default: " (%s)")
# For nested projects, shows full path: "ancestor/parent/project"
__wfw_ps1() {
    local fmt="${1:- (%s)}"
    local project_root

    project_root="$(__wfw_find_project_root)" || return

    # Build wireflow path from ancestors + current project
    local wfw_path=""
    local ancestor
    while IFS= read -r ancestor; do
        wfw_path+="$(basename "$ancestor")/"
    done < <(__wfw_find_ancestor_projects "$project_root")

    # Append current project name
    wfw_path+="$(basename "$project_root")"

    # shellcheck disable=SC2059
    printf "$fmt" "$wfw_path"
}
