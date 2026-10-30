# vim:ft=zsh
#
# cter ZDOTDIR bootstrap for zsh.
#
# GhosttyKit already uses a ZDOTDIR injection mechanism for zsh (setting ZDOTDIR
# to Ghostty's integration dir). cter also needs to run its integration, but
# we must restore the user's real ZDOTDIR immediately so that:
# - /etc/zshrc sets HISTFILE relative to the real ZDOTDIR/HOME (shared history)
# - zsh loads the user's real .zprofile/.zshrc normally (no wrapper recursion)
#
# We restore ZDOTDIR from (in priority order):
# - GHOSTTY_ZSH_ZDOTDIR (set by GhosttyKit when it overwrote ZDOTDIR)
# - CTER_ZSH_ZDOTDIR (set by cter when it overwrote a user-provided ZDOTDIR)
# - unset (zsh treats unset ZDOTDIR as $HOME)

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${CTER_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$CTER_ZSH_ZDOTDIR"
    builtin unset CTER_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
fi

{
    # zsh treats unset ZDOTDIR as if it were HOME. We do the same.
    builtin typeset _cter_file="${ZDOTDIR-$HOME}/.zshenv"
    [[ ! -r "$_cter_file" ]] || builtin source -- "$_cter_file"
} always {
    if [[ -o interactive ]]; then
        # We overwrote GhosttyKit's injected ZDOTDIR, so manually load Ghostty's
        # zsh integration if available.
        if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; then
            builtin typeset _cter_ghostty="$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
            [[ -r "$_cter_ghostty" ]] && builtin source -- "$_cter_ghostty"
        fi

        # Load cter integration (unless disabled)
        if [[ "${CTER_SHELL_INTEGRATION:-1}" != "0" && -n "${CTER_SHELL_INTEGRATION_DIR:-}" ]]; then
            builtin typeset _cter_integ="$CTER_SHELL_INTEGRATION_DIR/cter-zsh-integration.zsh"
            [[ -r "$_cter_integ" ]] && builtin source -- "$_cter_integ"
        fi
    fi

    builtin unset _cter_file _cter_ghostty _cter_integ
}
