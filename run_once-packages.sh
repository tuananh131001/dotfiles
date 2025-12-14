#!/bin/sh

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [ -d "$TPM_DIR" ]; then
  echo "TPM already exists, skipping clone."
else
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi
