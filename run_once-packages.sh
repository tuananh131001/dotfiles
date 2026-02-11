#!/bin/sh

TPM_DIR="$HOME/.tmux/plugins/tpm"
CONTINUUM_TPM_DIR="$HOME/.tmux/plugins/tmux-continuum"

if [ -d "$TPM_DIR" ]; then
  echo "TPM already exists, skipping clone."
else
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

if [ -d "$CONTINUUM_TPM_DIR" ]; then
  echo "Ghostty fork continuum already exists, skipping clone."
else
  git clone https://github.com/zuxfoucault/tmux-continuum_dev.git "$CONTINUUM_TPM_DIR"
  git checkout -b origin/feature/ghostty
fi
