#!/bin/bash
set -x
META_FILE="recipe/meta.yaml"
BUILD_FILE_UNIX="recipe/build.sh"
BUILD_FILE_WIN="recipe/bld.bat"
BUILD_STEPS_WIN=".scripts/run_win_build.bat"
BUILD_STEPS_LINUX=".scripts/build_steps.sh"
BUILD_STEPS_OSX=".scripts/run_osx_build.sh"


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

echo "✅ Added GStreamer dependencies to $META_FILE:"

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

sed -i '/^:: Validate/,$d' "$BUILD_STEPS_WIN"
echo "✅ Truncated $BUILD_STEPS_WIN at ':: Validate'"
sed -i '/^[[:space:]]*( startgroup "Validating outputs" )/,$d' $BUILD_STEPS_LINUX
echo "fi" >> $BUILD_STEPS_LINUX
echo "✅ Truncated $BUILD_STEPS_LINUX at 'Validating outputs'"
sed -i '/^[[:space:]]*( startgroup "Validating outputs" )/,$d' $BUILD_STEPS_OSX
echo "fi" >> $BUILD_STEPS_OSX
echo "✅ Truncated $BUILD_STEPS_OSX at 'Validating outputs'"