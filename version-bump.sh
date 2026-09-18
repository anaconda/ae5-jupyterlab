#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: version-bump.sh

Refresh pixi.lock in place with `pixi update --no-install` for all
dependencies on linux-64 and linux-aarch64. Does not commit or open a PR.
EOF
}

for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage >&2
            exit 1
            ;;
    esac
done

cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v pixi >/dev/null 2>&1; then
    echo "pixi is required on PATH" >&2
    exit 1
fi

if [ ! -f pixi.toml ] || [ ! -f pixi.lock ]; then
    echo "pixi.toml and pixi.lock are required" >&2
    exit 1
fi

pixi update --no-install

if git diff --quiet pixi.lock; then
    echo "pixi.lock unchanged"
else
    echo "Wrote pixi.lock"
fi
