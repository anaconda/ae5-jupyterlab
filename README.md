# Overriding JupyterLab in AE5

## Introduction

AE5 already ships JupyterLab inside the editor image
(`/opt/continuum/anaconda/envs/lab_launch`). This repository builds a
replacement JupyterLab environment that installs onto the shared
`/tools` volume at `/tools/jupyter`. Once those files are in place,
new sessions pick up `start_jupyterlab.sh` / `start_notebook.sh` from
`/tools` and run this environment instead of the baked-in one.

Use this when you want a newer JupyterLab, a patched
`anaconda-project-launcher`, or to test a lockfile bump before it is
baked into the editor image. Installation is reversible: remove
`/tools/jupyter` and sessions fall back to the image.

No existing sessions or deployments are affected. We recommend a
maintenance window only so that users do not create *new* sessions
while `/tools` is writable.

The latest files are always at:

- Installer project: [jupyter-installer.tar.bz2](https://airgap.svc.anaconda.com.s3.amazonaws.com/misc/jupyter-installer.tar.bz2)
- Packed environment (linux-64): [jupyter-linux-64.tar](https://airgap.svc.anaconda.com.s3.amazonaws.com/misc/jupyter-linux-64.tar)
- Packed environment (linux-aarch64): [jupyter-linux-aarch64.tar](https://airgap.svc.anaconda.com.s3.amazonaws.com/misc/jupyter-linux-aarch64.tar)

Untagged URLs track `master`. Dated and `-latest` / `-dev` suffixes
follow the same convention as the VSCode and RStudio tool repos.

## Installation

Log in as the storage manager (typically `anaconda-enterprise`), who
has write access to `/tools`.

### Step 1. Install JupyterLab onto `/tools/jupyter`

1. Start a session on any project.
2. Bring the installer and the pack for this machine's architecture
   into the project. If the cluster can reach the internet:

   ```
   curl -OL https://airgap.svc.anaconda.com.s3.amazonaws.com/misc/jupyter-installer.tar.bz2
   case $(uname -m) in
     arm64|aarch64) plat=linux-aarch64 ;;
     *)             plat=linux-64 ;;
   esac
   curl -OL "https://airgap.svc.anaconda.com.s3.amazonaws.com/misc/jupyter-${plat}.tar"
   ```

   Otherwise download them outside the cluster and upload them into
   the session.

3. Unpack the installer, place the pack in `downloads/`, and install:

   ```
   tar xfj jupyter-installer.tar.bz2
   mkdir -p Jupyter_Installer/downloads
   mv jupyter-linux-*.tar Jupyter_Installer/downloads/
   cd Jupyter_Installer
   PREFIX=/tools/jupyter bash install_jupyterlab.sh
   ```

   `install_jupyterlab.sh` unpacks the pixi-pack archive for this
   machine's architecture and runs `conda env create -p $PREFIX`.
   It does **not** require `pixi-pack` on PATH. Override `PREFIX` if
   you need a different location; the parent directory must exist and
   `$PREFIX` must be empty.

4. You may remove the tarballs and shut down this session.

### Step 2. Verify the installation

Start a new session and, from a terminal:

```
/tools/jupyter/start_jupyterlab.sh
```

_This should exit with an error_ — typically “address already in use”.
The important part is that the error comes from JupyterLab itself,
which confirms that `/tools/jupyter` is visible to AE5.

Opening a session with the JupyterLab editor should now serve this
install. AE5 discovers tools by the `start_*.sh` filename:
`start_jupyterlab.sh` and `start_notebook.sh` are the same script;
`TOOL_PACKAGE` selects `jupyter-lab` vs `jupyter-notebook`.

## Installer project (online / internal)

The installer archive is a pixi project (`pixi.toml` + `pixi.lock`).
AE5 can import it natively. That path is aimed at the AE5 team:

1. Import `jupyter-installer.tar.bz2` as a project and start a session.
2. Put `pixi-pack` on PATH (`pixi global install pixi-pack`).
3. Run `bash download_jupyterlab.sh` to pack both `linux-64` and
   `linux-aarch64` into `downloads/`.
4. Run `PREFIX=/tools/jupyter bash install_jupyterlab.sh`.

Bringup CI exercises this same download-then-install sequence inside
an `ae-editor-base` container.

## Notes

- The environment is a conda-style prefix: `$PREFIX/bin/jupyter-lab`
  with the start scripts sitting next to `bin/`.
- This launcher always uses its own directory as the env. The
  editor-image `start_notebook.sh` (the one under
  `/opt/continuum/scripts`) still searches `/tools/jupyter` as a
  custom env; installing here satisfies that search as well.
- `pixi.lock` tracks `linux-64` and `linux-aarch64`. CI bringup
  exercises linux-64; local testing on Apple Silicon uses linux-aarch64.
