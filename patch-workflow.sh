WORKFLOW_FILE="upstream/.github/workflows/conda-build.yml"
WORKFLOW_EXTENSION_FILE="workflow-extension.yml"
WINDOWS_WORKFLOW_FILE="upstream/.azure-pipelines/azure-pipelines-win.yml"
OSX_WORKFLOW_FILE="upstream/.azure-pipelines/azure-pipelines-osx.yml"
echo "Patching $WORKFLOW_FILE"
# Copy Windows and OSX workflow from azure pipeline
WINDOWS_MATRIX=$(sed -n '/^    matrix:$/,/^    maxParallel:/p' "$WINDOWS_WORKFLOW_FILE" \
    | sed '1d;$d' \
    | sed '/VMIMAGE:/d' \
    | sed 's/^      \([a-z].*\):$/          - CONFIG: \1/' \
    | sed '/^        CONFIG:/d' \
    | sed "s/^        UPLOAD_PACKAGES: 'True'/            UPLOAD_PACKAGES: False/")
WINDOWS_MATRIX=$(echo "$WINDOWS_MATRIX" | sed '/^          - CONFIG:/a\            os: windows\n            runs_on: ['"'"'windows-latest'"'"']')
OSX_MATRIX=$(sed -n '/^    matrix:$/,/^    maxParallel:/p' "$OSX_WORKFLOW_FILE" \
    | sed '1d;$d' \
    | sed '/VMIMAGE:/d' \
    | sed 's/^      \([a-z].*\):$/          - CONFIG: \1/' \
    | sed '/^        CONFIG:/d' \
    | sed "s/^        UPLOAD_PACKAGES: 'True'/            UPLOAD_PACKAGES: False/")
OSX_MATRIX=$(echo "$OSX_MATRIX" | sed \
    -e '/CONFIG: osx_64_/a\            os: macos\n            runs_on: ['"'"'macos-13'"'"']' \
    -e '/CONFIG: osx_arm64_/a\            os: macos\n            runs_on: ['"'"'macos-latest'"'"']')
# Combine both matrices
COMBINED_MATRIX="${WINDOWS_MATRIX}\n${OSX_MATRIX}"
# Insert into workflow file after "        include:"
sed -i '/^[[:space:]]*include:$/r /dev/stdin' "$WORKFLOW_FILE" <<< "$(echo -e "${COMBINED_MATRIX}")"
# Set working directory
sed -i '/^jobs:/,/^[^ ]/ {
    /^  build:/ {
        a\    defaults:
        a\      run:
        a\        working-directory: upstream
    }
}' "$WORKFLOW_FILE"
# Ignore pushes to main as a trigger
sed -i '/^  push:$/ {
    a\    branches-ignore:
    a\      - main
}' "$WORKFLOW_FILE"
# Disable package upload
sed -i 's/UPLOAD_PACKAGES:[[:space:]]*True/UPLOAD_PACKAGES: False/g' "$WORKFLOW_FILE"
# Remove unnecessary tokens
sed -i '/BINSTAR_TOKEN:\|FEEDSTOCK_TOKEN:\|STAGING_BINSTAR_TOKEN:/d' "$WORKFLOW_FILE"
# Remove present checkout step (has a hash so shouldn't depend on it for appending next step)
sed -i '/- name: Checkout code/,/uses: actions\/checkout@/d' "$WORKFLOW_FILE"
# Append (Apply GStreamer patches) and (Resolve NumPy Version)
sed -i '0,/^    steps:/{
    /^    steps:/ {
        a\    - uses: actions/checkout@v4
        a\      with:
        a\        submodules: recursive
        a\    - name: Apply GStreamer patches
        a\      run: ../patch-build.sh
        a\    - name: Resolve NumPy Version
        a\      id: resolve_np
        a\      shell: bash
        a\      run: |
        a\          set -euo pipefail
        a\          # Force NumPy >=2 for all supported Python versions
        a\          # Extract Python version from CONFIG string
        a\          PYTHON_VERSION=$(echo "${{ matrix.CONFIG }}" | grep -oP '"'"'python\\K\\d+\\.\\d+'"'"')
        a\          RAW_JSON=$(conda create -n _dryrun "python=${PYTHON_VERSION}" "numpy>=2.0" --dry-run --json --quiet 2>/dev/null || echo "{}")    a\          if echo "$RAW_JSON" | jq -e . >/dev/null 2>&1; then
        a\          NP_VERSION=$(echo "$RAW_JSON" | jq -r '"'"'.actions.LINK[]? | select(.name | test("^numpy$|^numpy-base$")) | .version'"'"' | head -n 1)
        a\          else
        a\          NP_VERSION=""
        a\          fi
        a\          if [ -z "$NP_VERSION" ] || [ "$NP_VERSION" = "null" ]; then
        a\          case "${{ matrix.python-version }}" in
        a\              "3.10") NP_VERSION="1.26";;
        a\              "3.11") NP_VERSION="2.0" ;;
        a\              "3.12") NP_VERSION="2.0" ;;
        a\              "3.13") NP_VERSION="2.4" ;;
        a\              *) NP_VERSION="2.4" ;;
        a\          esac
        a\          echo "⚠️ Using fallback NumPy $NP_VERSION"
        a\          else
        a\          echo "✅ Found NumPy version: $NP_VERSION"
        a\          fi
        a\          NP_SHORT=$(echo "$NP_VERSION" | cut -d. -f1,2)
        a\          echo "RESOLVED_NP=$NP_SHORT" >> $GITHUB_ENV
        a\          echo "NumPy major.minor = $NP_SHORT"
    }
}' "$WORKFLOW_FILE"
# Add numpy version to build steps
sed -i '/^      env:/a\        EXTRA_CB_OPTIONS: "--numpy ${{ env.RESOLVED_NP }}"' "$WORKFLOW_FILE"
# Add the upload steps to the workflow
cat "$WORKFLOW_EXTENSION_FILE" >> "$WORKFLOW_FILE"
echo "✅ Patched $WORKFLOW_FILE"