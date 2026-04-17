@echo on

:: Convert paths to forward slashes for CMake
set "LIBRARY_PREFIX_FWD=%LIBRARY_PREFIX:\=/%"
set "PREFIX_FWD=%PREFIX:\=/%"
set "SRC_DIR_FWD=%SRC_DIR:\=/%"
set "PYTHON_FWD=%PYTHON:\=/%"
set "SP_DIR_FWD=%SP_DIR:\=/%"
set "PNG_LIB_FWD=%PNG_LIB:\=/%"
set "TIFF_LIB_FWD=%TIFF_LIB:\=/%"

set PKG_CONFIG_PATH=%LIBRARY_PREFIX%\lib\pkgconfig;%LIBRARY_PREFIX%\share\pkgconfig
set CFLAGS=%CFLAGS% -I%LIBRARY_PREFIX%\include
set LDFLAGS=%LDFLAGS% -L%LIBRARY_PREFIX%\lib

:: Find PNG and TIFF libraries
set PNG_LIB=%LIBRARY_PREFIX%\lib\libpng.lib
if not exist "%PNG_LIB%" set PNG_LIB=%LIBRARY_PREFIX%\lib\png.lib
set PNG_LIB_FWD=%PNG_LIB:\=/%

set TIFF_LIB=%LIBRARY_PREFIX%\lib\libtiff.lib
if not exist "%TIFF_LIB%" set TIFF_LIB=%LIBRARY_PREFIX%\lib\tiff.lib
set TIFF_LIB_FWD=%TIFF_LIB:\=/%

mkdir build
cd build

cmake "%SRC_DIR%\opencv" ^
    -GNinja ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX_FWD%" ^
    -DCMAKE_PREFIX_PATH="%LIBRARY_PREFIX_FWD%" ^
    -DOPENCV_EXTRA_MODULES_PATH="%SRC_DIR_FWD%/opencv_contrib/modules" ^
    -DBUILD_opencv_python3=ON ^
    -DPYTHON3_EXECUTABLE="%PYTHON_FWD%" ^
    -DPYTHON3_INCLUDE_DIR="%PREFIX_FWD%/include" ^
    -DPYTHON3_PACKAGES_PATH="%SP_DIR_FWD%" ^
    -DWITH_GSTREAMER=ON ^
    -DWITH_FFMPEG=ON ^
    -DENABLE_PKG_CONFIG=ON ^
    -DWITH_WIN32UI=ON ^
    -DWITH_MSMF=ON ^
    -DBUILD_EXAMPLES=OFF ^
    -DBUILD_TESTS=OFF ^
    -DBUILD_PERF_TESTS=OFF ^
    -DPNG_LIBRARY="%PNG_LIB_FWD%" ^
    -DPNG_PNG_INCLUDE_DIR="%LIBRARY_PREFIX_FWD%/include" ^
    -DTIFF_LIBRARY="%TIFF_LIB_FWD%" ^
    -DTIFF_INCLUDE_DIR="%LIBRARY_PREFIX_FWD%/include"

if errorlevel 1 exit /b 1

ninja install
if errorlevel 1 exit /b 1