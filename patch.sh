#!/bin/bash
META_FILE="recipe/meta.yaml"
BUILD_FILE_UNIX="recipe/build.sh"
BUILD_FILE_WIN="recipe/bld.bat"
WORKFLOW_FILE=".github/workflows/conda-build.yml"
WORKFLOW_EXTENSION_FILE="../workflow-extension.yml"

echo "Patching $META_FILE"
sed -i '/^  host:$/a\
    # GStreamer dependencies (added by patch)\
    - gstreamer\
    - gst-plugins-base\
    - gst-plugins-good\
    - gst-plugins-bad\
    - gst-plugins-ugly\
    - gst-libav\
    - glib\
    - libxml2' "$META_FILE"

echo "✅ Added GStreamer dependencies to $META_FILE"

echo "Patching $BUILD_FILE_UNIX"
if grep -q -- "-DWITH_GSTREAMER" "$BUILD_FILE_UNIX"; then
    # Replace -DWITH_GSTREAMER=0 with =1 (handles various formats)
    sed -i 's/-DWITH_GSTREAMER=[0-9]\+/-DWITH_GSTREAMER=1/g' "$BUILD_FILE_UNIX"
    sed -i 's/-DWITH_GSTREAMER[^-]*-/-DWITH_GSTREAMER=1 \\/g' "$BUILD_FILE_UNIX"
    echo "✅ Updated existing -DWITH_GSTREAMER to =1"
else
    # Append after ${CMAKE_ARGS} line
    sed -i '/${CMAKE_ARGS}.*\\/a\    -DWITH_GSTREAMER=1                                                    \\' "$BUILD_FILE_UNIX"
    echo "✅ Appended -DWITH_GSTREAMER=1 after \${CMAKE_ARGS}"
fi

echo "Patching $BUILD_FILE_WIN"
if grep -qi -- "-DWITH_GSTREAMER" "$BUILD_FILE_WIN"; then
    # Replace -DWITH_GSTREAMER=0 with =1
    sed -i 's/-DWITH_GSTREAMER=0/-DWITH_GSTREAMER=1/gi' "$BUILD_FILE_WIN"
    echo "✅ Updated existing -DWITH_GSTREAMER to =1"
else
    # Append directly under 'cmake -LAH -G "Ninja"' line
    sed -i '/^cmake -LAH -G "Ninja".*\^/a\    -DWITH_GSTREAMER=1                                                              ^' "$BUILD_FILE_WIN"
    echo "✅ Appended -DWITH_GSTREAMER=1 under cmake line"
fi

echo "Patching $WORKFLOW_FILE"
sed -i 's/UPLOAD_PACKAGES:[[:space:]]*True/UPLOAD_PACKAGES: False/g' $WORKFLOW_FILE
echo "✅ Set UPLOAD_PACKAGES: False"
sed -i '/BINSTAR_TOKEN:\|FEEDSTOCK_TOKEN:\|STAGING_BINSTAR_TOKEN:/d' $WORKFLOW_FILE
echo "✅ Removed definition lines for: BINSTA_TOKEN, FEEDSTOCK_TOKEN, STAGING_BINSTAR_TOKEN"
sed -i '/^    steps:/a\      defaults:\n        run:\n          working-directory: upstream'
echo "✅ Pointed to ./upstream as the working directory for steps"
cat "$WORKFLOW_EXTENSION_FILE" >> "$WORKFLOW_FILE"
echo "✅ Appended $WORKFLOW_EXTENSION_FILE to $WORKFLOW_FILE"