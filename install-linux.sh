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
