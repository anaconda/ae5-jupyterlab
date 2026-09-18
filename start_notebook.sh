#!/bin/bash

echo "+-- START: AE5 JupyterLab Launcher ---"
set -e

if [[ $TOOL_PACKAGE = jupyterlab ]]; then
    pname=jupyter-lab
else
    pname=jupyter-notebook
fi

JUPYTER_ENV=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONDA_ROOT=${CONDA_ROOT:-/opt/continuum/anaconda}

echo "| Tool home: $JUPYTER_ENV"
echo "| Using environment: $JUPYTER_ENV"
source "$CONDA_ROOT/bin/activate" "$JUPYTER_ENV"

args=($pname '--NotebookApp.trust_xheaders=True' '--no-browser')
[[ $pname = jupyter-notebook ]] && args+=('--NotebookApp.show_banner=False')
# Don't check for updates
[[ $pname = jupyter-lab ]] && args+=('--LabApp.check_for_updates_class=jupyterlab.NeverCheckForUpdate')
# Our proxy provides the auth, so no need for a password or token
args+=('--NotebookApp.token=' '--NotebookApp.password=')
# Remove quit button and warning banners
args+=('--NotebookApp.quit_button=False')
# Use interactive shell
args+=('--NotebookApp.terminado_settings={"shell_command":["'"$SHELL"'","-i"]}')
[[ $TOOL_PORT ]] && args+=('--port' $TOOL_PORT)
[[ $TOOL_ADDRESS ]] && args+=('--ip' $TOOL_ADDRESS)
# anaconda-project-lab's proxy needs this...
[[ $TOOL_HOST ]] && args+=('--PrototypeManager.extra_hosts=["'"$TOOL_HOST"'"]')
[[ $TOOL_HOST ]] && export BOKEH_ALLOW_WS_ORIGIN=$TOOL_HOST
[[ $TOOL_PREFIX ]] && args+=("--NotebookApp.base_url=$TOOL_PREFIX")
if [[ $TOOL_IFRAME_HOSTS ]]; then
    left='--NotebookApp.tornado_settings={"headers":{"Content-Security-Policy":"'
    center="frame-ancestors 'self' $TOOL_IFRAME_HOSTS"
    right='"}}'
    args+=("$left$center$right")
fi
echo "| Command line: ${args[@]}"
echo "+-- END: AE5 JupyterLab Launcher ---"
exec "${args[@]}"
