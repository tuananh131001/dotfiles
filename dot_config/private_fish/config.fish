if status is-interactive
    # Commands to run in interactive sessions can go here
end
starship init fish | source
zoxide init fish | source

set -x EDITOR /opt/homebrew/bin/nvim
set -x VISUAL /opt/homebrew/bin/nvim

