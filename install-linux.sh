sudo apt install tmux
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz

sudo apt install zsh
chsh -s $(which zsh)

# Starship

curl -sS https://starship.rs/install.sh | sh

# rbenv
sudo apt install rbenv

# nodenv
git clone https://github.com/nodenv/nodenv.git ~/.nodenv

# tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# zsh -jump
git clone https://github.com/agkozak/zsh-z.git ~/.zprezto-contrib/zsh-z

echo "Installing rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
echo "Installing rust apps..."
cargo install bob-nvim
bob install stable
bob use stable

git config --global user.name 'AnhNT'
git config --global user.email 'tuananh131001@gmail.com'
git config --global credential.helper

echo "Installing tmux plugin manager..."
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions


LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
