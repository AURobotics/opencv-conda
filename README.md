# Opencv with GStreamer support

## Problem

opencv wheels `opencv-python`, `opencv-headless`, `opencv-contrib` along with `opencv` distributed over conda-forge, all are not built with GStreamer support.

It is possible to build opencv wheels against GStreamer on Windows and OSX using either system-level GStreamer packages or the [official GStreamer wheels](https://pypi.org/org/gstreamer/) with somewhat minimal patches to point to the GStreamer library files and the `gst-inspect-1.0` executable, with the option to also include hooks or patches for `pyinstaller` or similar tools.

The official GStreamer wheels have proven to be a struggle for their maintainers to build for Linux.

On Linux, it is currently difficult to build opencv against GStreamer without having to do so for every popular linux distribution and do so for each of its releases. This is what some distributions, like Ubuntu, have present in their package repositories - opencv built against GStreamer and other system libraries from their repositories.

## Solution

Conda provides packages in a reproduceable way on all platforms, making opencv built against conda GStreamer packages work as long as conda is able to provide the necessary environment at runtime. Conda brings its own packages for almost everything, which prevents ABI mismatches for packages other than `glibc`. For broad `glibc` ABI compatibility, simply compiling on the oldest known `glibc` in a widely in-use non-EOL linux distribution will ensure forward compatibility.


## Technical Details

This project is an automated set of patches on the already-established `opencv` conda-forge package, whose build workflows are found at: https://github.com/conda-forge/opencv-feedstock/

### Workflow Summary

**Automatic updater**\
The updater workflow [update-upstream.yml](./.github/workflows/update-upstream.yml) checks if the upstream feedstock has had any updates and pushes the updated submodule reference.

The `automated-builds` branch is recreated every time the updater workflow is run, and it pulls the main build workflow [conda-build.yml](./upstream/.github/workflows/conda-build.yml) and patches it with the "master-patch" that will later apply the build patches.

### Patch Summary

#### Build Workflow Patch
- Included [Windows](./upstream/.azure-pipelines/azure-pipelines-win.yml) and [OSX](./upstream/.azure-pipelines/azure-pipelines-osx.yml) matrices in the main `conda-build.yml`
- Set the correct runners for the new matrices
- Set `UPLOAD_PACKAGES` to `'FALSE'` - with quotes since checkers expect upper-cased boolean strings
- Unset unnecessary upload tokens `BINSTAR_TOKEN`, `FEEDSTOCK_TOKEN`, `STAGING_BINSTAR_TOKEN`
- Added a `numpy>=2` resolver/ enforcer for maximum API compatibility
- Added "Upload artifact" steps after each build job (from [workflow-extension.yml](./workflow-extension.yml))
- Added a "publish" job to upload artifacts to the [prefix.dev channel `aurobotics`](https://prefix.dev/aurobotics/) (from [workflow-extension.yml](./workflow-extension.yml))
- Pull the patched workflow out of the submodule but set its build job's working directory to the [submodules folder](./upstream/)

#### Build Scripts Patches
- Added GStreamer packages under `host` dependencies in [`meta.yaml`](./upstream/recipe/meta.yaml)
- Set the CMake flag `DWITH_GSTREAMER` to `1` in [`bld.bat`](./upstream/recipe/bld.bat) and [`build.sh`](./upstream/recipe/build.sh)
- Removed the `Validating outputs` group from the [Linux](./upstream/.scripts/build_steps.sh), [OSX](./upstream/.scripts/run_osx_build.sh) and [Windows](./upstream/.scripts/run_win_build.bat) build scripts

## Project Lifecycle