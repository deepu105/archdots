#!/usr/bin/env bash
set -euo pipefail

repo="${LLAMA_CPP_REPO:-$HOME/Workspace/llms/llama.cpp}"
build_dir="${LLAMA_CPP_BUILD_DIR:-$repo/build-hip}"
target="${LLAMA_AMDGPU_TARGETS:-gfx1151}"

if [[ ! -d "$repo/.git" ]]; then
    mkdir -p "$(dirname "$repo")"
    git clone https://github.com/ggml-org/llama.cpp "$repo"
fi

git -C "$repo" pull --ff-only

cmake -S "$repo" -B "$build_dir" -G Ninja \
    -DGGML_HIP=ON \
    -DAMDGPU_TARGETS="$target" \
    -DCMAKE_BUILD_TYPE=Release

cmake --build "$build_dir" --config Release -j "$(nproc)" --target llama-server llama-bench
