#!/bin/bash

set -euo pipefail
SCRIPT_NAME=$(basename "${BASH_SOURCE[0]}")
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}"

expected_version=$(sed -nE 's@.*/jupyterlab-([0-9.]+)-[^/]*\.conda@\1@p' pixi.lock | head -1)
if [ -z "$expected_version" ]; then
	echo "Could not parse jupyterlab version from pixi.lock" 1>&2
	exit 1
fi
container_name=ae5-jupyterlab-test

install_pixi_pack() {
	export HOME=/opt/continuum
	export CONDA_ROOT=/opt/continuum/anaconda
	export PATH="${CONDA_ROOT}/bin:/usr/local/bin:${HOME}/.pixi/bin:/opt/continuum/.pixi/bin:${PATH}"
	if command -v pixi-pack >/dev/null 2>&1; then
		return 0
	fi
	if command -v pixi >/dev/null 2>&1; then
		pixi global install pixi-pack
		export PATH="${HOME}/.pixi/bin:/opt/continuum/.pixi/bin:${PATH}"
		if command -v pixi-pack >/dev/null 2>&1; then
			return 0
		fi
	fi
	case $(uname -m) in
		arm64|aarch64) pack_arch=aarch64-unknown-linux-musl ;;
		*)             pack_arch=x86_64-unknown-linux-musl ;;
	esac
	curl -fsSL -o /tmp/pixi-pack \
		"https://github.com/quantco/pixi-pack/releases/latest/download/pixi-pack-${pack_arch}"
	chmod +x /tmp/pixi-pack
	export PATH="/tmp:${PATH}"
	command -v pixi-pack >/dev/null 2>&1
}

if [ -d /opt/continuum/anaconda/conda-meta ]; then

	err_exit() { echo "-- FAILED --"; exit 1; }
	if [ "$SCRIPT_DIR" = "/testing" ]; then
		cp -a /testing /tmp/ae5-jupyterlab
		cd /tmp/ae5-jupyterlab
	fi
	export HOME=/opt/continuum
	export CONDA_ROOT=/opt/continuum/anaconda
	install_pixi_pack || err_exit
	export TOOL_PROJECT_URL=@ TOOL_HOST=@ TOOL_PORT=8086 TOOL_ADDRESS=0.0.0.0
	export TOOL_PACKAGE=jupyterlab
	echo ""
	bash download_jupyterlab.sh 2>&1
	echo ""
	PREFIX=/tools/jupyter bash install_jupyterlab.sh 2>&1
	echo ""
	mkdir -p /opt/continuum/project
	cp -r test_project/* /opt/continuum/project/
	cd /opt/continuum/project
	echo ""
	bash /tools/jupyter/start_jupyterlab.sh 2>&1
	exit 0

fi

# Only one container can run at a time
if [ -n "$(docker ps -aq -f name="^${container_name}$")" ]; then
	echo "Container $container_name is already running" 1>&2
	exit 1
fi

# Query GCR for the latest production container version
if [ -z "${IMAGE_VER:-}" ]; then
	# This is a bit of a hack
	IMAGE_VER=$(curl -s -u "_json_key:$AE_GCR_KEY" \
		https://gcr.io/v2/continuum-compute/ae-editor-base/tags/list | \
		jq -r '.tags[]' | tail -1 | sed -E 's@-(arm64|amd64)@@' || :)
	if [ -z "$IMAGE_VER" ]; then
		echo "Could not determine ae-editor-base image version" 1>&2
		exit 1
	fi
fi
image_name=gcr.io/continuum-compute/ae-editor-base:${IMAGE_VER}
if [ -n "${GITHUB_OUTPUT:-}" ]; then
	echo "image_ver=${IMAGE_VER}" >> "$GITHUB_OUTPUT"
	echo "expected_version=${expected_version}" >> "$GITHUB_OUTPUT"
fi

# Launch the container in detach mode but give it a name we can track
container_cleanup() {
	docker stop "$container_name" >/dev/null 2>&1 || :
	docker rm "$container_name" >/dev/null 2>&1 || :
}
trap container_cleanup EXIT
cmd=(docker pull "$image_name")
echo "> ${cmd[*]}"
"${cmd[@]}" >/dev/null
cmd=(docker run --detach --name "$container_name" \
	 --publish 8086:8086 --env TOOL_OWNER="$USER" --env TOOL_PACKAGE=bash \
	 --tmpfs /tools:exec -v "${SCRIPT_DIR}:/testing:ro" \
	 "$image_name" bash /testing/${SCRIPT_NAME})
echo "> ${cmd[*]}"
"${cmd[@]}" >/dev/null
docker ps --all --no-trunc | grep -E "${container_name}$" || :
echo ""

# Scan the logs of the container until 1) the container dies;
# 2) it emits the "-- FAILED --" error; or 3) it emits a line
# from start_notebook.sh indicating JupyterLab is running.
timestamp=
while IFS= read -r line; do
	echo "${line#* }"
	case "$line" in
	*"- FAILED -"*) break ;;
	*"- END: AE5 JupyterLab Launcher -"*) timestamp="${line%% *}"; break ;;
	esac
done < <(docker logs "$container_name" --follow --timestamps)

if [ -z "$timestamp" ]; then
	echo "JupyterLab failed to stabilize" 1>&2
	exit 1
fi

capture_attempt=$(node capture.mjs "$expected_version" 2>&1 && echo "@@success@@" || :)

docker logs "$container_name" --since="$timestamp" | sed 1d

echo "${capture_attempt%*@@success@@}"
[[ "$capture_attempt" = *"@@success@@" ]] || exit 1
