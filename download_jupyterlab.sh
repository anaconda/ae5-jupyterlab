#!/bin/bash

echo "+----------------------------+"
echo "| AE5 JupyterLab Downloader  |"
echo "+----------------------------+"

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v pixi-pack >/dev/null 2>&1; then
    echo "ERROR: pixi-pack is not on PATH" >&2
    echo "Install it (e.g. pixi global install pixi-pack) and retry." >&2
    exit 1
fi

if [ ! -f pixi.toml ] || [ ! -f pixi.lock ]; then
    echo "ERROR: pixi.toml and pixi.lock must be in the same directory as this script" >&2
    exit 1
fi

if ! mkdir -p downloads; then
    echo "ERROR: could not create the downloads directory" >&2
    exit 1
fi

cache=downloads/.pixi-pack-cache
mkdir -p "$cache"

for platform in linux-64 linux-aarch64; do
    out="downloads/jupyter-${platform}.tar"
    echo "Packing lab-launch for ${platform} -> ${out}"
    pixi-pack \
        --environment lab-launch \
        --platform "$platform" \
        --output-file "$out" \
        --use-cache "$cache" \
        pixi.toml
done

echo "Packed:"
ls -l downloads/jupyter-linux-64.tar downloads/jupyter-linux-aarch64.tar
