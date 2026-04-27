#!/bin/bash
set -x

WORKFLOW_FILE="upstream/.github/workflows/conda-build.yml"
WORKFLOW_EXTENSION_FILE="workflow-extension.yml"
WINDOWS_WORKFLOW_FILE="upstream/.azure-pipelines/azure-pipelines-win.yml"
OSX_WORKFLOW_FILE="upstream/.azure-pipelines/azure-pipelines-osx.yml"

echo "Patching $WORKFLOW_FILE"

# Extract and process Windows matrix
WINDOWS_MATRIX=$(perl -ne '
    if (/^\s{4}matrix:/ ... /^\s{4}maxParallel:/) {
        next if /^\s{4}matrix:/ || /^\s{4}maxParallel:/;
        next if /VMIMAGE:/;
        if (/^\s{6}([a-z].*):$/) { print "          - CONFIG: $1\n"; }
        elsif (/^\s{8}CONFIG:/) { next; }
        elsif (/^\s{8}UPLOAD_PACKAGES: '\''True'\''/) { print "            UPLOAD_PACKAGES: '\''False'\''\n"; }
    }
' "$WINDOWS_WORKFLOW_FILE")

# Add os/runs_on to Windows
WINDOWS_MATRIX=$(echo "$WINDOWS_MATRIX" | perl -pe '
    if (/^          - CONFIG:/) { $_ .= "            os: windows\n            runs_on: ['\''windows-latest'\'']\n"; }
')

# Extract and process OSX matrix
OSX_MATRIX=$(perl -ne '
    if (/^\s{4}matrix:/ ... /^\s{4}maxParallel:/) {
        next if /^\s{4}matrix:/ || /^\s{4}maxParallel:/;
        next if /VMIMAGE:/;
        if (/^\s{6}([a-z].*):$/) { print "          - CONFIG: $1\n"; }
        elsif (/^\s{8}CONFIG:/) { next; }
        elsif (/^\s{8}UPLOAD_PACKAGES: '\''True'\''/) { print "            UPLOAD_PACKAGES: '\''False'\''\n"; }
    }
' "$OSX_WORKFLOW_FILE")

# Add os/runs_on to OSX
OSX_MATRIX=$(echo "$OSX_MATRIX" | perl -pe '
    if (/CONFIG: osx_64_/) { $_ .= "            os: macos\n            runs_on: ['\''macos-26-intel'\'']\n"; }
    elsif (/CONFIG: osx_arm64_/) { $_ .= "            os: macos\n            runs_on: ['\''macos-26'\'']\n"; }
')

# Combine matrices
COMBINED_MATRIX="${WINDOWS_MATRIX}"$'\n'"${OSX_MATRIX}"

# Insert matrices after "        include:"
echo "$COMBINED_MATRIX" | perl -i -pe '
    BEGIN { $matrix = do { local $/; <STDIN> }; }
    if (/^\s+include:/) { $_ .= $matrix; }
' "$WORKFLOW_FILE"

# Set working directory
perl -i -pe '
    if (/^  build:/) { $_ .= "    defaults:\n      run:\n        working-directory: upstream\n"; }
' "$WORKFLOW_FILE"

# Ignore pushes to main
perl -i -pe '
    if (/^  push:/) { $_ .= "    branches-ignore:\n      - main\n"; }
' "$WORKFLOW_FILE"

# Disable package upload
perl -i -pe "s/UPLOAD_PACKAGES:\s*True/UPLOAD_PACKAGES: 'False'/g" "$WORKFLOW_FILE"

# Remove tokens
perl -i -ne 'print unless /BINSTAR_TOKEN|FEEDSTOCK_TOKEN|STAGING_BINSTAR_TOKEN/' "$WORKFLOW_FILE"

# Remove old checkout step
perl -i -ne 'print unless /- name: Checkout code/ .. /uses: actions\/checkout@/' "$WORKFLOW_FILE"

# Append new steps after first "    steps:"
perl -i -pe '
    if (/^    steps:/ && !$done) {
        $done = 1;
        $_ .= <<'\''YAMLEOF'\'';
    - uses: actions/checkout@v6
      with:
        submodules: recursive
    - name: Apply GStreamer patches
      shell: bash
      run: ../patch-build.sh
    - name: Resolve NumPy Version
      id: resolve_np
      shell: bash
      run: |
          set -euo pipefail
          PYTHON_VERSION=$(echo "${{ matrix.CONFIG }}" | perl -ne '\''print $1 if /python(\d+\.\d+)/'\'')
          RAW_JSON=$(conda create -n _dryrun "python=${PYTHON_VERSION}" "numpy>=2.0" --dry-run --json --quiet 2>/dev/null || echo "{}")
          if echo "$RAW_JSON" | jq -e . >/dev/null 2>&1; then
          NP_VERSION=$(echo "$RAW_JSON" | jq -r '\''.actions.LINK[]? | select(.name | test("^numpy$|^numpy-base$")) | .version'\'' | head -n 1)
          else
          NP_VERSION=""
          fi
          if [ -z "$NP_VERSION" ] || [ "$NP_VERSION" = "null" ]; then
          case "$PYTHON_VERSION" in
              "3.10") NP_VERSION="1.26";;
              "3.11") NP_VERSION="2.0" ;;
              "3.12") NP_VERSION="2.0" ;;
              "3.13") NP_VERSION="2.4" ;;
              *) NP_VERSION="2.4" ;;
          esac
          echo "⚠️ Using fallback NumPy $NP_VERSION"
          else
          echo "✅ Found NumPy version: $NP_VERSION"
          fi
          NP_SHORT=$(echo "$NP_VERSION" | cut -d. -f1,2)
          echo "RESOLVED_NP=$NP_SHORT" >> $GITHUB_ENV
          echo "NumPy major.minor = $NP_SHORT"
YAMLEOF
    }
' "$WORKFLOW_FILE"

# Add NumPy to build steps
perl -i -pe '
    if (/^      env:/) { $_ .= "        EXTRA_CB_OPTIONS: \"--numpy \${{ env.RESOLVED_NP }}\"\n"; }
' "$WORKFLOW_FILE"

# Append extension
cat "$WORKFLOW_EXTENSION_FILE" >> "$WORKFLOW_FILE"

echo "✅ Patched $WORKFLOW_FILE"