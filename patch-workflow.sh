WORKFLOW_FILE="upstream/.github/workflows/conda-build.yml"
WORKFLOW_EXTENSION_FILE="workflow-extension.yml"

echo "Patching $WORKFLOW_FILE"
sed -i 's/UPLOAD_PACKAGES:[[:space:]]*True/UPLOAD_PACKAGES: False/g' "$WORKFLOW_FILE"
sed -i '/BINSTAR_TOKEN:\|FEEDSTOCK_TOKEN:\|STAGING_BINSTAR_TOKEN:/d' "$WORKFLOW_FILE"
sed -i '/- name: Checkout code/,/uses: actions\/checkout@/d' "$WORKFLOW_FILE"
sed -i '/^jobs:/,/^[^ ]/ {
    /^  build:/ {
        a\    defaults:
        a\      run:
        a\        working-directory: upstream
    }
}' "$WORKFLOW_FILE"
sed -i '/^    steps:/ {
    a\    - uses: actions/checkout@v4
    a\      with:
    a\        submodules: recursive
    a\    - name: Apply GStreamer patches
    a\      run: ../patch-build.sh
}' "$WORKFLOW_FILE"
sed -i '/^on:/,/^[a-z]/{ /push:/a\    branches-ignore:\n      - upstream-update }' "$WORKFLOW_FILE"
cat "$WORKFLOW_EXTENSION_FILE" >> "$WORKFLOW_FILE"
echo "✅ Patched $WORKFLOW_FILE"