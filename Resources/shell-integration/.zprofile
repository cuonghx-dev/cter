# vim:ft=zsh
#
# Compatibility shim: with the current integration model, cter restores
# ZDOTDIR in .zshenv so this file should never be reached. If it is, restore
# ZDOTDIR and behave like vanilla zsh by sourcing the user's .zprofile.

if [[ -n "${GHOSTTY_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$GHOSTTY_ZSH_ZDOTDIR"
    builtin unset GHOSTTY_ZSH_ZDOTDIR
elif [[ -n "${CTER_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$CTER_ZSH_ZDOTDIR"
    builtin unset CTER_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
fi

builtin typeset _cter_file="${ZDOTDIR-$HOME}/.zprofile"
[[ ! -r "$_cter_file" ]] || builtin source -- "$_cter_file"
builtin unset _cter_file
