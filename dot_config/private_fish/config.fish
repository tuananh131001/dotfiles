if status is-interactive
    # Commands to run in interactive sessions can go here
end
__cached_init starship init fish --print-full-init
__cached_init zoxide init fish

set -x EDITOR ~/.local/share/bob/nvim-bin/nvim
set -x VISUAL ~/.local/share/bob/nvim-bin/nvim

fish_add_path /usr/local/mysql/bin/
fish_add_path /Users/anh.nt/.cargo/bin
fish_add_path ~/.bun/bin

# uv
fish_add_path "/Users/anh.nt/.local/bin"
fish_add_path $HOME/.local/bin

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
 set -x  XDEBUG_MODE coverage


# Auto update claude code
# set -x DISABLE_AUTOUPDATER 1 

__cached_init mise activate fish --shims

# Alias
alias amida="cd ~/Documents/amida"
alias claude-danger="claude --dangerously-skip-permissions"
alias amida-logs='cd /Users/anh.nt/Projects/hankoya/github-migration-athanko/hankoya_kagura/storage/logs/amida'
alias ssh_teamlike_1_prod='ssh -i ~/.ssh/teamlike_aws_ec2 -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession \
      --parameters portNumber=%p --region ap-northeast-1 --profile teamlikeprod" anh.nt@i-0a5d7ac47695f65f4'
alias deep50='mpv https://www.youtube.com/watch?v=YdEk_oLsIec'
alias deep25='mpv https://www.youtube.com/watch?v=l15BFT7RTEk'
alias ae-update='claude plugin marketplace update agent-expert; and claude plugin update agent-expert@agent-expert'

# pnpm
set -gx PNPM_HOME "/Users/anh.nt/Library/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

#nvim bob
fish_add_path ~/.local/share/bob/nvim-bin

# The next line updates PATH for the Google Cloud SDK.
fish_add_path /Users/anh.nt/Projects/swat/google-cloud-sdk/bin

# Pi
fish_add_path "/Users/anh.nt/.local/share/mise/installs/node/22.22.2/bin"

# opencode
fish_add_path /Users/anh.nt/.opencode/bin

# Homebrew auto-update
set -x HOMEBREW_NO_AUTO_UPDATE 1

# VLC
alias vlc='/Applications/VLC.app/Contents/MacOS/VLC'
