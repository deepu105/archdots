# archdots

Minimal Arch Linux dotfiles for a local-first AI development setup using niri, DankMaterialShell, OpenCode, and llama.cpp.

This repository is intentionally small and sanitized. It does not include private hostnames, Wi-Fi names, tokens, SSH/GPG material, browser/editor state, shell history, KDE Connect keys, LM Studio state, or machine-specific mount points.

## What This Includes

- A minimal `.profile` with local AI environment variables and useful aliases.
- A minimal Zsh setup with `ZDOTDIR=$HOME/.config/zsh`.
- A reusable niri config with DMS keybindings.
- A small DMS settings file with Catppuccin-inspired defaults.
- OpenCode config for a local llama.cpp OpenAI-compatible endpoint.
- Optional OpenRouter OpenCode config example with no API key included.
- Scripts to build llama.cpp with HIP and run `llama-server`.

## What This Does Not Include

- Secrets or API keys.
- Personal shell history.
- Private machine names, Wi-Fi names, IPs, or account data.
- KDE, GNOME, browser, editor, or cloud-provider state.
- Full Arch installation automation.

## Suggested Packages

Install only what you need. This is the package set I would start with on a fresh Arch machine:

```bash
paru -S niri dms-shell dms-shell-niri swayidle matugen wl-clipboard cliphist \
  xwayland-satellite xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
  kitty zsh zsh-completions zsh-autosuggestions fzf zoxide fastfetch \
  git base-devel cmake ninja jq ripgrep fd eza bat btop yazi \
  nodejs npm rustup go python python-pip docker docker-compose \
  mesa vulkan-radeon libva-mesa-driver mesa-vdpau radeontop \
  rocm-hip-sdk rocm-opencl-sdk rocblas hipblaslt
```

You also need OpenCode. Follow the official install instructions from [opencode.ai](https://opencode.ai/) and keep the config from this repo under `.config/opencode/opencode.json`.

For AMD GPUs, check your target with:

```bash
rocminfo | rg -i 'gfx[0-9]+'
```

The llama.cpp build script defaults to `gfx1151`, which is the target used for the Radeon 8060S on the ASUS ROG Flow Z13. Change `AMDGPU_TARGETS` if your GPU is different.

## Install Dotfiles

This repo is designed to be used with GNU Stow from the repository root.

```bash
git clone https://github.com/deepu105/archdots.git ~/archdots
cd ~/archdots
stow .
```

If you already have files in the same locations, review them first. Do not blindly overwrite a live setup.

## Local Model Layout

The scripts use these default paths:

```text
~/Workspace/llms/llama.cpp
~/Models
```

You can override them with environment variables:

```bash
export LLAMA_CPP_REPO="$HOME/Workspace/llms/llama.cpp"
export LLAMA_MODEL_ROOT="$HOME/Models"
export LLAMA_AMDGPU_TARGETS="gfx1151"
```

Put your GGUF models under `~/Models`, for example:

```text
~/Models/Qwen3.6-27B-GGUF/Qwen3.6-27B-Q4_K_M.gguf
```

## Build llama.cpp

```bash
scripts/update_llama_cpp.sh
```

This clones or updates llama.cpp and builds `llama-server` and `llama-bench` with HIP support.

## Start Local llama-server

```bash
llamaServer
```

Or run the script directly:

```bash
scripts/llama_server.sh
```

The server listens on:

```text
http://127.0.0.1:8080/v1
```

OpenCode uses that endpoint from `.config/opencode/opencode.json`.

## Optional OpenRouter

If you also want frontier models through OpenRouter, copy the example config and set your API key in your shell or secret manager:

```bash
export OPENROUTER_API_KEY="your-key-here"
cp .config/opencode/opencode.openrouter.example.json ~/.config/opencode/opencode.json
```

Do not commit real API keys.

## Validate

```bash
niri validate -c .config/niri/config.kdl
bash -n scripts/llama_server.sh
bash -n scripts/update_llama_cpp.sh
zsh -n .profile
zsh -n .zshenv
zsh -n .config/zsh/.zshrc
```

## Notes

This is a starting point, not a distro. Expect to adjust display names, scaling, GPU target, package list, and keybindings for your machine.
