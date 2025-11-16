# =============================================================================
# Interactive Editor Functions
# =============================================================================
# Support functions for interactively editing project and workflow files.
# This file is sourced by lib/core.sh.
# =============================================================================

# Usage examples:
# edit_files "config.yml"
# edit_files "file1.txt" "file2.txt" "file3.txt"

# Function to detect if editor supports vim-style splits
is_vim_like() {
    local editor="$1"
    local editor_base=$(basename "$editor")
    
    case "$editor_base" in
        vim|nvim|neovim|gvim|mvim|vimx)
            return 0
            ;;
        vi)
            # Check if vi is actually vim in disguise
            if "$editor" --version 2>&1 | grep -qi "vim"; then
                return 0
            fi
            ;;
    esac
    return 1
}

# Function to check if editor supports multiple files well
supports_multiple_files() {
    local editor="$1"
    local editor_base=$(basename "$editor")
    
    case "$editor_base" in
        vim|nvim|neovim|gvim|mvim|vimx|vi|emacs|gedit|kate|code|subl)
            return 0
            ;;
    esac
    return 1
}

# Function to open files in the best available editor
edit_files() {
    local files=("$@")
    local editor=""
    local editor_args=()
    
    # Validate that files array is not empty
    if [ ${#files[@]} -eq 0 ]; then
        echo "Error: No files specified" >&2
        return 1
    fi
    
    # Priority order: vim > nvim > vi > VISUAL > EDITOR > nano > emacs
    if command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v nvim >/dev/null 2>&1; then
        editor="nvim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    elif [ -n "$VISUAL" ] && command -v "$VISUAL" >/dev/null 2>&1; then
        editor="$VISUAL"
    elif [ -n "$EDITOR" ] && command -v "$EDITOR" >/dev/null 2>&1; then
        editor="$EDITOR"
    elif command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v emacs >/dev/null 2>&1; then
        editor="emacs"
    elif command -v ed >/dev/null 2>&1; then
        editor="ed"
    else
        echo "Error: No suitable text editor found" >&2
        return 1
    fi
    
    # Handle multiple files
    if [ ${#files[@]} -gt 1 ]; then
        if is_vim_like "$editor"; then
            # Vim-like editors: use vertical splits
            editor_args=("-O" "--")
        elif ! supports_multiple_files "$editor"; then
            # Editors that don't handle multiple files well: edit sequentially
            echo "Note: Opening files sequentially (editor doesn't support splits)" >&2
            for file in "${files[@]}"; do
                "$editor" "$file" || return $?
            done
            return 0
        fi
        # Else: editor can handle multiple files (like emacs), pass them all
    fi
    
    # Open the editor
    "$editor" "${editor_args[@]}" "${files[@]}"
    return $?
}
