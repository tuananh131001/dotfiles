if status is-interactive
# Commands to run in interactive sessions can go here
end
export PATH="/opt/homebrew/bin:$PATH"
starship init fish | source
zoxide init fish | source
export EDITOR="nvim"
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate fish)"
alias claude-danger="claude --dangerously-skip-permissions"
