WORKFLOW_FILE="upstream/.github/workflows/conda-build.yml"
WORKFLOW_EXTENSION_FILE="workflow-extension.yml"

echo "Patching $WORKFLOW_FILE"
sed -i 's/UPLOAD_PACKAGES:[[:space:]]*True/UPLOAD_PACKAGES: False/g' "$WORKFLOW_FILE"
sed -i '/BINSTAR_TOKEN:\|FEEDSTOCK_TOKEN:\|STAGING_BINSTAR_TOKEN:/d' "$WORKFLOW_FILE"
sed -i '/^jobs:/,/^[^ ]/ {
    /^  build:/ {
        a\    defaults:
        a\      run:
        a\        working-directory: upstream
    }
}' "$WORKFLOW_FILE"
sed -i '/^    steps:/a\
      - uses: actions\/checkout@v4\
        with:\
          submodules: recursive\
\
      - name: Apply GStreamer patches\
        run: ..\/patch.sh' "$WORKFLOW_FILE"
cat "$WORKFLOW_EXTENSION_FILE" >> "$WORKFLOW_FILE"
echo "✅ Patched $WORKFLOW_FILE"