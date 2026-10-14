#!/usr/bin/env bash
set -euo pipefail

echo "=== Updating Fedora ==="
sudo dnf upgrade -y

echo "=== Installing system packages ==="
sudo dnf install -y \
    git \
    curl \
    wget \
    nodejs \
    npm \
    python3 \
    python3-pip \
    podman \
    jq \
    gcc \
    gcc-c++ \
    make

echo "=== Installing Ollama ==="
curl -fsSL https://ollama.com/install.sh | sh

echo "=== Starting Ollama ==="
systemctl --user enable --now ollama || true

echo "=== Installing Aider ==="
pip3 install --user aider-chat

echo "=== Installing Gemini CLI ==="
npm install -g @google/gemini-cli

echo "=== Installing OpenCode ==="
npm install -g opencode-ai

echo "=== Pulling local coding models ==="
ollama pull qwen3-coder
ollama pull deepseek-r1

echo ""
echo "Installation Complete"
echo ""
echo "Verify:"
echo "gemini --version"
echo "opencode --version"
echo "aider --version"
echo "ollama list"
