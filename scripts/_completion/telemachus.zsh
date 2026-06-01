#compdef telemachus telemachus-backup telemachus-calendar telemachus-contacts telemachus-cookbook telemachus-docs telemachus-gallery telemachus-mail telemachus-mcp telemachus-memory telemachus-notes telemachus-personal telemachus-preset telemachus-research telemachus-sessions telemachus-signature telemachus-skills telemachus-tasks telemachus-theme telemachus-webhook
# Zsh tab-completion for the telemachus umbrella + sub-CLIs.
#
# Drop in any directory on $fpath, e.g.:
#     fpath=(/path/to/telemachus-ui/scripts/_completion $fpath)
#     autoload -U compinit; compinit
#
# Then `telemachus <tab>` completes subcommands; `telemachus mail <tab>`
# completes mail subcommands; `telemachus-mail <tab>` works the same.

_telemachus_scripts_dir() {
    local self="${(%):-%x}"
    while [[ -L "$self" ]]; do self="$(readlink "$self")"; done
    cd "${self:h}/.." && pwd
}

typeset -gA _telemachus_subs

_telemachus_refresh() {
    _telemachus_subs=()
    local dir="$(_telemachus_scripts_dir)"
    local py="$dir/../venv/bin/python"
    [[ -x "$py" ]] || py="$(command -v python3)"
    local f sub help_out commands
    for f in "$dir"/telemachus-*; do
        [[ -x "$f" ]] || continue
        case "$f" in
            *.bak|*.pyc|*.pre-*) continue ;;
        esac
        sub="${${f:t}#telemachus-}"
        help_out=$("$py" "$f" --help 2>/dev/null) || continue
        commands=$(echo "$help_out" | grep -oE '\{[a-z0-9_,-]+\}' | head -1 \
            | tr -d '{}' | tr ',' ' ')
        _telemachus_subs[$sub]="$commands"
    done
}

_telemachus() {
    [[ ${#_telemachus_subs} -eq 0 ]] && _telemachus_refresh

    local cmd="${words[1]}"

    if [[ "$cmd" == "telemachus" ]]; then
        if (( CURRENT == 2 )); then
            local -a subs=(${(k)_telemachus_subs} help)
            _describe 'subcommand' subs
            return
        fi
        local sub="${words[2]}"
        if [[ "$sub" == "help" ]] && (( CURRENT == 3 )); then
            local -a subs=(${(k)_telemachus_subs})
            _describe 'subcommand' subs
            return
        fi
        if (( CURRENT == 3 )); then
            local -a sc=(${(s/ /)_telemachus_subs[$sub]})
            _describe 'command' sc
            return
        fi
        return
    fi

    # telemachus-foo <tab>
    local sub="${cmd#telemachus-}"
    if (( CURRENT == 2 )); then
        local -a sc=(${(s/ /)_telemachus_subs[$sub]})
        _describe 'command' sc
        return
    fi
}

_telemachus "$@"
