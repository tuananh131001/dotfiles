if status is-interactive
# Commands to run in interactive sessions can go here
end
export PATH="/opt/homebrew/bin:$PATH"
starship init fish | source
zoxide init fish | source
export EDITOR="nvim"
