#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...
# Start rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
alias buj="bundle update josys-configurator"
mi_core()
{
bundle update josys-configurator
rails db:create
rails db:migrate
rails db:migrate:with_data
rails db:seed_fu
rails db:seed
rake rbac:seed_permission_matrix
rake rbac:assign_admin_to_superadmin
bin/rails db:seed_fu
bin/rails db:seed
}
alias sc="bin/rails s -b 'ssl://localhost:3022?key=./localhost.key&cert=./localhost.crt'"
clean_db(){
rails db:drop db:create db:migrate
rails db:migrate RAILS_ENV=test
}
PROMPT='%{$fg[yellow]%}[%D{%f/%m/%y} %D{%L:%M:%S}] '$PROMPT
eval "$(starship init zsh)"


# pnpm
export PNPM_HOME="/Users/anh.nt/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=`which chromium`
export ELASTIC_PASSWORD="xctKaB-GWssm_7mkFFQR"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
export PATH="$HOME/.nodenv/bin:$PATH"
export PATH=/Users/$USER/.local/share/bob/nvim-bin:$PATH
