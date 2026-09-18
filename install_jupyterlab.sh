#!/bin/bash

echo "+---------------------------+"
echo "| AE5 JupyterLab Installer  |"
echo "+---------------------------+"

set -euo pipefail

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONDA_ROOT=${CONDA_ROOT:-/opt/continuum/anaconda}

echorun() {
    echo "> $*"
    "$@" 2>&1 | sed 's@^@| @'
    return "${PIPESTATUS[0]}"
}

case $(uname -m) in
    arm64|aarch64) PLAT=linux-aarch64 ;;
    *)             PLAT=linux-64 ;;
esac

PACK=
for candidate in "$PWD/downloads/jupyterlab-${PLAT}.tar" \
                 "$SCRIPTDIR/downloads/jupyterlab-${PLAT}.tar"; do
    if [ -f "$candidate" ]; then
        PACK=$candidate
        break
    fi
done
if [ -z "$PACK" ]; then
    echo "ERROR: missing downloads/jupyterlab-${PLAT}.tar"
    echo "(Have you unpacked jupyter-blobs.tar.bz2, or run download_jupyterlab.sh?)"
    exit 1
fi

missing=
for sfile in start_notebook.sh custom.css custom.js; do
    [ -f "$SCRIPTDIR/$sfile" ] || missing="$missing $sfile"
done
if [ -n "$missing" ]; then
    echo "ERROR: missing support files:$missing"
    exit 1
fi

PREFIX=${PREFIX:-/tools/jupyter}
echo "| Install prefix: ${PREFIX}"
echo "| Pack: ${PACK}"

if [ ! -d "$PREFIX" ]; then
    parent=$(dirname "$PREFIX")
    if [ ! -d "$parent" ]; then
        echo "ERROR: install parent $parent does not exist"
        exit 1
    elif ! mkdir -p "$PREFIX"; then
        echo "ERROR: could not create install directory"
        exit 1
    fi
elif [ ! -w "$PREFIX" ]; then
    echo "ERROR: install location is not writable"
    ls -ald "$PREFIX"
    id
    exit 1
elif [ -n "$(ls -A "$PREFIX")" ]; then
    echo "ERROR: install location is not empty"
    ls -al "$PREFIX"
    exit 1
fi

if [ ! -f "$CONDA_ROOT/etc/profile.d/conda.sh" ]; then
    echo "ERROR: conda not found at $CONDA_ROOT"
    exit 1
fi
# shellcheck disable=SC1091
source "$CONDA_ROOT/etc/profile.d/conda.sh"

unpack=$(mktemp -d)
cleanup() { rm -rf "$unpack"; }
trap cleanup EXIT

echo "- Unpacking pixi-pack archive"
echorun tar xf "$PACK" -C "$unpack"

echo "- Creating conda prefix"
conda config --set add_pip_as_python_dependency false
(
    cd "$unpack"
    echorun conda env create -p "$PREFIX" --file environment.yml
)

echo "- Installing support scripts"
cp "$SCRIPTDIR/start_notebook.sh" "$PREFIX/start_notebook.sh"
ln -s start_notebook.sh "$PREFIX/start_jupyterlab.sh"
chmod +x "$PREFIX/start_notebook.sh"

echo "- Configuring JupyterLab environment"
# shellcheck disable=SC1091
source "$CONDA_ROOT/bin/activate" "$PREFIX"

cmd() {
    echo "$ $*"
    "$@" 2>&1 | sed 's@^@| @'
    return "${PIPESTATUS[0]}"
}

cmd jupyter labextension disable "@jupyterlab/apputils-extension:announcements"
cmd jupyter labextension disable "@jupyterlab/extensionmanager-extension"
cmd jupyter labextension lock || :

for dst in "$PREFIX"/lib/*/site-packages/*/static/custom/; do
    if [ -d "$dst" ]; then
        cp "$SCRIPTDIR"/custom.* "$dst"
    fi
done

need_rebuild=no
labext_list=$(jupyter labextension list 2>&1 || true)
if printf '%s\n' "$labext_list" | grep -q '^Build recommended'; then
    echo "Rebuild required due to extensions"
    need_rebuild=yes
fi

if [ "$need_rebuild" = yes ]; then
    echo "- Rebuilding JupyterLab using nodejs"
    cmd conda create -c conda-forge -p /tmp/nodejs nodejs --yes
    if [ ! -f /tmp/nodejs/conda-meta/history ]; then
        exit 1
    fi
    export PATH=/tmp/nodejs/bin:$PATH
    cmd jupyter lab build
    labext_list=$(jupyter labextension list 2>&1 || true)
fi

echo "- Sanity check"
printf '%s\n' "$labext_list" | sed 's@^@| @'
server_list=$(jupyter server extension list 2>&1 || true)
printf '%s\n' "$server_list" | sed 's@^@| @'
error=no
if ! printf '%s\n' "$labext_list" | grep -q 'anaconda.project.launcher.*OK'; then
    error=yes
    echo "ERROR: anaconda-project-launcher front end is not enabled"
fi
if ! printf '%s\n' "$server_list" | grep -q 'anaconda.project.launcher.*OK'; then
    error=yes
    echo "ERROR: anaconda-project-launcher back end is not enabled"
fi
if [ "$error" = yes ]; then
    exit 1
fi

if [ "$need_rebuild" = yes ]; then
    cmd jupyter lab clean
    cmd jlpm cache clean
    cmd npm cache clean --force
    rm -rf /tmp/nodejs
fi

find "$PREFIX" ! -perm -g=w -exec chmod -R g=u {} \;

echo "Installed. You can shut down this session, and/or remove downloaded files."
