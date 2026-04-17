#!/bin/bash
set -ex

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export CFLAGS="$CFLAGS -I$PREFIX/include"
export LDFLAGS="$LDFLAGS -L$PREFIX/lib -Wl,-rpath-link,$PREFIX/lib"

# Force linking against conda's libpng and libtiff
export CMAKE_LIBRARY_PATH="$PREFIX/lib"
export CMAKE_INCLUDE_PATH="$PREFIX/include"

mkdir -p build && cd build

cmake "$SRC_DIR/opencv" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_LIBRARY_PATH="$PREFIX/lib" \
    -DCMAKE_INCLUDE_PATH="$PREFIX/include" \
    -DOPENCV_EXTRA_MODULES_PATH="$SRC_DIR/opencv_contrib/modules" \
    -DBUILD_opencv_python3=ON \
    -DPYTHON3_EXECUTABLE="$PYTHON" \
    -DPYTHON3_INCLUDE_DIR="$PREFIX/include/python$PY_VER" \
    -DPYTHON3_PACKAGES_PATH="$SP_DIR" \
    -DWITH_GSTREAMER=ON \
    -DWITH_FFMPEG=ON \
    -DENABLE_PKG_CONFIG=ON \
    -DBUILD_PROTOBUF=OFF \
    -DPROTOBUF_UPDATE_FILES=OFF \
    -DProtobuf_PROTOC_EXECUTABLE="$PREFIX/bin/protoc" \
    -DProtobuf_INCLUDE_DIR="$PREFIX/include" \
    -DProtobuf_LIBRARY="$PREFIX/lib/libprotobuf.so" \
    -DPNG_LIBRARY="$PREFIX/lib/libpng.so" \
    -DPNG_PNG_INCLUDE_DIR="$PREFIX/include" \
    -DTIFF_LIBRARY="$PREFIX/lib/libtiff.so" \
    -DTIFF_INCLUDE_DIR="$PREFIX/include" \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DWITH_GTK=ON \
    -DWITH_GTK_2_X=OFF

ninja install