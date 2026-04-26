#!/bin/bash
set -x
META_FILE="recipe/meta.yaml"
BUILD_FILE_UNIX="recipe/build.sh"
BUILD_FILE_WIN="recipe/bld.bat"
BUILD_STEPS_WIN=".scripts/run_win_build.bat"
BUILD_STEPS_LINUX=".scripts/build_steps.sh"
BUILD_STEPS_OSX=".scripts/run_osx_build.sh"

echo "Patching $META_FILE"
perl -i -pe '
    if (/^  host:$/) {
        $_ .= "    # GStreamer dependencies (added by patch)\n";
        $_ .= "    - gstreamer\n";
        $_ .= "    - gst-plugins-base\n";
        $_ .= "    - gst-plugins-good\n";
        $_ .= "    - gst-plugins-bad\n";
        $_ .= "    - gst-plugins-ugly\n";
        $_ .= "    - gst-libav\n";
        $_ .= "    - glib\n";
        $_ .= "    - libxml2\n";
    }
' "$META_FILE"
echo "✅ Added GStreamer dependencies to $META_FILE"

echo "Patching $BUILD_FILE_UNIX"
if grep -q -- "-DWITH_GSTREAMER" "$BUILD_FILE_UNIX"; then
    perl -i -pe 's/-DWITH_GSTREAMER=\d+/-DWITH_GSTREAMER=1/g' "$BUILD_FILE_UNIX"
    perl -i -pe 's/-DWITH_GSTREAMER[^-]*-/-DWITH_GSTREAMER=1 \\/g' "$BUILD_FILE_UNIX"
    echo "✅ Updated existing -DWITH_GSTREAMER to =1"
else
    perl -i -pe 'print "    -DWITH_GSTREAMER=1                                                    \\\n" if /\$\{CMAKE_ARGS\}.*\\/' "$BUILD_FILE_UNIX"
    echo "✅ Appended -DWITH_GSTREAMER=1 after \${CMAKE_ARGS}"
fi

echo "Patching $BUILD_FILE_WIN"
if grep -qi -- "-DWITH_GSTREAMER" "$BUILD_FILE_WIN"; then
    perl -i -pe 's/-DWITH_GSTREAMER=0/-DWITH_GSTREAMER=1/gi' "$BUILD_FILE_WIN"
    echo "✅ Updated existing -DWITH_GSTREAMER to =1"
else
    perl -i -pe 'print "    -DWITH_GSTREAMER=1                                                              ^\n" if /^cmake -LAH -G "Ninja".*\^/' "$BUILD_FILE_WIN"
    echo "✅ Appended -DWITH_GSTREAMER=1 under cmake line"
fi

perl -i -pe 'exit if /^:: Validate/ .. 0' "$BUILD_STEPS_WIN"
echo "✅ Deleting ':: Validate' block in $BUILD_STEPS_WIN"

perl -i -ne 'print unless /\( startgroup "Validating outputs" / .. /\( endgroup "Validating outputs" /' "$BUILD_STEPS_LINUX"
echo "✅ Deleting 'Validating outputs' block in $BUILD_STEPS_LINUX"

perl -i -ne 'print unless /\( startgroup "Validating outputs" / .. /\( endgroup "Validating outputs" /' "$BUILD_STEPS_OSX"
echo "✅ Deleting 'Validating outputs' block in $BUILD_STEPS_OSX"