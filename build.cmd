@echo off
setlocal enabledelayedexpansion

set MESA_BRANCH=main
set VKLOADER_BRANCH=main
set WINSDK_VER=10.0.26100.0
set ENABLE_DBGSYM=0
set ENABLE_INSTALLER=1
set ENABLE_CLEAN=1

set PATH=%CD%\winflexbison;%PATH%
set VSCMD_SKIP_SENDTELEMETRY=1

rem *** check dependencies ***

where /q python.exe || (
  echo ERROR: "python.exe" not found
  exit /b 1
)

where /q pip.exe || (
  echo ERROR: "pip.exe" not found
  exit /b 1
)

where /q cmake.exe || (
  echo ERROR: "cmake.exe" not found
  exit /b 1
)

where /q meson.exe || (
  pip install meson
  where /q meson.exe || (
    echo ERROR: "meson.exe" not found
    exit /b 1
  )
)

python -c "import mako" 2>nul || (
  pip install mako packaging
  python -c "import mako" 2>nul || (
    echo ERROR: "mako" module not found for python
    exit /b 1
  )
)

python -c "import yaml" 2>nul || (
  pip install pyyaml
  python -c "import yaml" 2>nul || (
    echo ERROR: "yaml" module not found for python
    exit /b 1
  )
)

where /q git.exe || (
  echo ERROR: "git.exe" not found
  exit /b 1
)

where /q curl.exe || (
  echo ERROR: "curl.exe" not found
  exit /b 1
)

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

where /q cmake.exe || (
  echo ERROR: "cmake.exe" not found
  exit /b 1
)

where /q ninja.exe || (
  curl -Lsf -o ninja-win.zip https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-win.zip || exit /b 1
  %SZIP% x -bb0 -y ninja-win.zip 1>nul 2>nul || exit /b 1
  del ninja-win.zip 1>nul 2>nul
)

rem *** Visual Studio environment ***

set __VSCMD_ARG_NO_LOGO=1
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -prerelease -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
if "!VS!" equ "" (
  echo ERROR: Visual Studio installation not found
  exit /b 1
)

rem *** download sources ***

if not exist winflexbison (
  echo Downloading win_flex_bison
  mkdir winflexbison
  pushd winflexbison
  curl -sfL -o win_flex_bison.zip https://github.com/lexxmark/winflexbison/releases/download/v2.5.25/win_flex_bison-2.5.25.zip || exit /b 1
  %SZIP% x -bb0 -y win_flex_bison.zip 1>nul 2>nul || exit /b 1
  del win_flex_bison.zip 1>nul 2>nul
  popd
)

if not exist mesa.src (
  echo Cloning Mesa sources from git
  git clone https://gitlab.freedesktop.org/mesa/mesa.git mesa.src
)

echo Updating Mesa source tree
cd mesa.src

rem Git options that help with Windows git clones
git config core.ignoreCase true
git config core.filemode false

if "x%ENABLE_CLEAN%" NEQ "x0" (
  git reset
  git checkout .
  git checkout -t origin/%MESA_BRANCH% || git checkout %MESA_BRANCH%
  git pull
  del src\microsoft\compiler\dxil_md5.c
  del src\microsoft\compiler\dxil_md5.h
  git apply --verbose ..\patches\mesa-unused-variables.patch || exit /b 1
  git apply --verbose ..\patches\mesa-dozen-minImageTransferGranularity.patch || exit /b 1
  git apply --verbose ..\patches\mesa-dozen-msaa-2x.patch || exit /b 1
  git apply --verbose ..\patches\mesa-dxil-signature.patch || exit /b 1
  git apply --verbose ..\patches\mesa-glon12-queries-infinite-recursion-fix.patch || exit /b 1
  git apply --verbose ..\patches\mesa-dozen-assert-imagetype.patch || exit /b 1
  git apply --verbose ..\patches\mesa-dozen-dummy-for-unbound-descriptors.patch || exit /b 1
)
cd ..

if not exist vkloader.src (
  echo Cloning Vulkan loader from git
  git clone https://github.com/KhronosGroup/Vulkan-Loader.git vkloader.src
)

echo Updating Vulkan loader source tree
cd vkloader.src

rem Git options that help with Windows git clones
git config core.ignoreCase true
git config core.filemode false

if "x%ENABLE_CLEAN%" NEQ "x0" (
  git reset
  git checkout .
  git checkout -t origin/%VKLOADER_BRANCH% || git checkout %VKLOADER_BRANCH%
  git pull
  git apply --verbose ..\patches\vkloader-install-pdb.patch || exit /b 1
  git apply --verbose ..\patches\vkloader-no-d3dmappinglayers.patch || exit /b 1
)
cd ..

if "x%ENABLE_DBGSYM%"=="x0" (
  set CMAKE_BUILDTYPE=Release
  set MESON_BUILDTYPE=release
  set MESON_VSRUNTIME=mt
  set MESON_NDEBUG=true
  type nul > install-config.iss
)
if "x%ENABLE_DBGSYM%"=="x1" (
  set CMAKE_BUILDTYPE=RelWithDebInfo
  set MESON_BUILDTYPE=debugoptimized
  set MESON_VSRUNTIME=mt
  set MESON_NDEBUG=true
  (
    echo #define ENABLE_DBGSYM
  ) > install-config.iss
)

rem remove old install prefixes
if "x%ENABLE_CLEAN%" NEQ "x0" (
  echo Removing old installation prefixes
  rd /s/q .\mesa.prefix.gl 1>nul 2>nul
  rd /s/q .\mesa.prefix.vk 1>nul 2>nul
  rd /s/q .\vkloader.prefix 1>nul 2>nul

  rd /s/q .\mesa.build.vk.x86 1>nul 2>nul
  rd /s/q .\mesa.build.gl.x86 1>nul 2>nul
  rd /s/q .\mesa.build.vk.arm64 1>nul 2>nul
  rd /s/q .\mesa.build.gl.arm64 1>nul 2>nul
  rd /s/q .\mesa.build.vk.x64 1>nul 2>nul
  rd /s/q .\mesa.build.gl.x64 1>nul 2>nul

  rd /s/q .\vkloader.build.x86 1>nul 2>nul
  rd /s/q .\vkloader.build.arm64 1>nul 2>nul
  rd /s/q .\vkloader.build.x64 1>nul 2>nul
)

set CFGID_X86=x64_x86
set CFGID_X64=x64
set CFGID_ARM64=x64_arm64

if "x%PROCESSOR_ARCHITECTURE%"=="xARM64" (
  set CFGID_X86=arm64_x86
  set CFGID_X64=arm64_x64
  set CFGID_ARM64=arm64
)

rem x86 build
rem Always ignore output of first vcvarsall.bat /clean_env, because it errors if the environment is already clean. *sigh*
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" /clean_env >nul 2>nul
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" %CFGID_X86% %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

if not exist "mesa.build.vk.x86\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  meson setup ^
    mesa.build.vk.x86 ^
    mesa.src ^
    --reconfigure ^
    --cross-file=cross-x86.txt ^
    --prefix="%CD%\mesa.prefix.vk\x86" ^
    --default-library=static ^
    --buildtype=%MESON_BUILDTYPE% ^
    -Dmin-windows-version=10 ^
    -Db_ndebug=%MESON_NDEBUG% ^
    -Db_vscrt=%MESON_VSRUNTIME% ^
    -Dllvm=disabled ^
    -Dplatforms=windows ^
    -Dspirv-to-dxil=false ^
    -Dshared-glapi=enabled ^
    -Dgallium-drivers="" ^
    -Dvulkan-drivers=microsoft-experimental ^
    -Dvulkan-icd-dir="%CD%\mesa.prefix.vk\x86\bin" ^
    -Dopengl=false ^
    -Dgles1=disabled ^
    -Dgles2=disabled ^
    -Degl=disabled || exit /b 1
)
ninja -C mesa.build.vk.x86 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x86\dxil.dll" "%CD%\mesa.prefix.vk\x86\bin\"

if not exist "mesa.build.gl.x86\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  meson setup ^
    mesa.build.gl.x86 ^
    mesa.src ^
    --reconfigure ^
    --cross-file=cross-x86.txt ^
    --prefix="%CD%\mesa.prefix.gl\x86" ^
    --default-library=static ^
    --buildtype=%MESON_BUILDTYPE% ^
    -Dmin-windows-version=10 ^
    -Db_ndebug=%MESON_NDEBUG% ^
    -Db_vscrt=%MESON_VSRUNTIME% ^
    -Dllvm=disabled ^
    -Dplatforms=windows ^
    -Dgallium-drivers=d3d12,zink ^
    -Dspirv-to-dxil=false ^
    -Dshared-glapi=enabled ^
    -Dopengl=true ^
    -Dgles1=enabled ^
    -Dgles2=enabled ^
    -Degl=enabled || exit /b 1
)
ninja -C mesa.build.gl.x86 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x86\dxil.dll" "%CD%\mesa.prefix.gl\x86\bin\"
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x86\dxcompiler.dll" "%CD%\mesa.prefix.gl\x86\bin\"

if not exist "vkloader.build.x86\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  cmake -G Ninja ^
    -S vkloader.src ^
    -B vkloader.build.x86 ^
    -DCMAKE_BUILD_TYPE=%CMAKE_BUILDTYPE% ^
    -DCMAKE_INSTALL_PREFIX="%CD%\vkloader.prefix\x86" ^
    -DUPDATE_DEPS=ON || exit /b 1
)
cmake --build vkloader.build.x86 || exit /b 1
cmake --install vkloader.build.x86 || exit /b 1


rem arm64 build

call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" %CFGID_ARM64% %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

if not exist "mesa.build.vk.arm64\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  meson setup ^
    mesa.build.vk.arm64 ^
    mesa.src ^
    --reconfigure ^
    --cross-file=cross-arm64.txt ^
    --prefix="%CD%\mesa.prefix.vk\arm64" ^
    --default-library=static ^
    --buildtype=%MESON_BUILDTYPE% ^
    -Dmin-windows-version=10 ^
    -Db_ndebug=%MESON_NDEBUG% ^
    -Db_vscrt=%MESON_VSRUNTIME% ^
    -Dllvm=disabled ^
    -Dplatforms=windows ^
    -Dspirv-to-dxil=false ^
    -Dshared-glapi=enabled ^
    -Dgallium-drivers="" ^
    -Dvulkan-drivers=microsoft-experimental ^
    -Dvulkan-icd-dir="%CD%\mesa.prefix.vk\arm64\bin" ^
    -Dopengl=false ^
    -Dgles1=disabled ^
    -Dgles2=disabled ^
    -Degl=disabled || exit /b 1
)
ninja -C mesa.build.vk.arm64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\arm64\dxil.dll" "%CD%\mesa.prefix.vk\arm64\bin\"

if not exist "mesa.build.gl.arm64\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  meson setup ^
    mesa.build.gl.arm64 ^
    mesa.src ^
    --reconfigure ^
    --cross-file=cross-arm64.txt ^
    --prefix="%CD%\mesa.prefix.gl\arm64" ^
    --default-library=static ^
    --buildtype=%MESON_BUILDTYPE% ^
    -Dmin-windows-version=10 ^
    -Db_ndebug=%MESON_NDEBUG% ^
    -Db_vscrt=%MESON_VSRUNTIME% ^
    -Dllvm=disabled ^
    -Dplatforms=windows ^
    -Dgallium-drivers=d3d12,zink ^
    -Dspirv-to-dxil=false ^
    -Dshared-glapi=enabled ^
    -Dopengl=true ^
    -Dgles1=enabled ^
    -Dgles2=enabled ^
    -Degl=enabled || exit /b 1
)
ninja -C mesa.build.gl.arm64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\arm64\dxil.dll" "%CD%\mesa.prefix.gl\arm64\bin\"
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\arm64\dxcompiler.dll" "%CD%\mesa.prefix.gl\arm64\bin\"

if not exist "vkloader.build.arm64\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  cmake -G Ninja ^
    -S vkloader.src ^
    -B vkloader.build.arm64 ^
    -DCMAKE_BUILD_TYPE=%CMAKE_BUILDTYPE% ^
    -DCMAKE_INSTALL_PREFIX="%CD%\vkloader.prefix\arm64" ^
    -DUPDATE_DEPS=ON || exit /b 1
)
cmake --build vkloader.build.arm64 || exit /b 1
cmake --install vkloader.build.arm64 || exit /b 1


rem x64 build

call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" %CFGID_X64% %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

if not exist "mesa.build.vk.x64\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  meson setup ^
    mesa.build.vk.x64 ^
    mesa.src ^
    --reconfigure ^
    --cross-file=cross-x64.txt ^
    --prefix="%CD%\mesa.prefix.vk\x64" ^
    --default-library=static ^
    --buildtype=%MESON_BUILDTYPE% ^
    -Dmin-windows-version=10 ^
    -Db_ndebug=%MESON_NDEBUG% ^
    -Db_vscrt=%MESON_VSRUNTIME% ^
    -Dllvm=disabled ^
    -Dplatforms=windows ^
    -Dspirv-to-dxil=false ^
    -Dshared-glapi=enabled ^
    -Dgallium-drivers="" ^
    -Dvulkan-drivers=microsoft-experimental ^
    -Dvulkan-icd-dir="%CD%\mesa.prefix.vk\x64\bin" ^
    -Dopengl=false ^
    -Dgles1=disabled ^
    -Dgles2=disabled ^
    -Degl=disabled || exit /b 1
)
ninja -C mesa.build.vk.x64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x64\dxil.dll" "%CD%\mesa.prefix.vk\x64\bin\"

if not exist "mesa.build.gl.x64\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  meson setup ^
    mesa.build.gl.x64 ^
    mesa.src ^
    --reconfigure ^
    --cross-file=cross-x64.txt ^
    --prefix="%CD%\mesa.prefix.gl\x64" ^
    --default-library=static ^
    --buildtype=%MESON_BUILDTYPE% ^
    -Dmin-windows-version=10 ^
    -Db_ndebug=%MESON_NDEBUG% ^
    -Db_vscrt=%MESON_VSRUNTIME% ^
    -Dllvm=disabled ^
    -Dplatforms=windows ^
    -Dgallium-drivers=d3d12,zink ^
    -Dspirv-to-dxil=false ^
    -Dshared-glapi=enabled ^
    -Dopengl=true ^
    -Dgles1=enabled ^
    -Dgles2=enabled ^
    -Degl=enabled || exit /b 1
)
ninja -C mesa.build.gl.x64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x64\dxil.dll" "%CD%\mesa.prefix.gl\x64\bin\"
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x64\dxcompiler.dll" "%CD%\mesa.prefix.gl\x64\bin\"

if not exist "vkloader.build.x64\build.ninja" (
  set MUST_CLEAN=1
) else (
  set MUST_CLEAN=0
)
if "x%ENABLE_CLEAN%%MUST_CLEAN%" NEQ "x00" (
  cmake -G Ninja ^
    -S vkloader.src ^
    -B vkloader.build.x64 ^
    -DCMAKE_BUILD_TYPE=%CMAKE_BUILDTYPE% ^
    -DCMAKE_INSTALL_PREFIX="%CD%\vkloader.prefix\x64" ^
    -DUPDATE_DEPS=ON || exit /b 1
)
cmake --build vkloader.build.x64 || exit /b 1
cmake --install vkloader.build.x64 || exit /b 1

python patch-icds.py || exit /b 1

rem build installer
if "x%ENABLE_INSTALLER%"=="x1" (
  python gen-version.py || exit /b 1

  "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x64\signtool.exe" sign /a /n "Uplink Laboratories" /fd SHA256 /td SHA256 /tr http://timestamp.digicert.com ^
    mesa.prefix.vk\x86\bin\*.dll mesa.prefix.vk\x86\bin\*.exe vkloader.prefix\x86\bin\*.dll ^
    mesa.prefix.vk\x64\bin\*.dll mesa.prefix.vk\x64\bin\*.exe vkloader.prefix\x64\bin\*.dll ^
    mesa.prefix.vk\arm64\bin\*.dll mesa.prefix.vk\arm64\bin\*.exe vkloader.prefix\arm64\bin\*.dll ^
    mesa.prefix.gl\x86\bin\*.dll ^
    mesa.prefix.gl\x64\bin\*.dll ^
    mesa.prefix.gl\arm64\bin\*.dll || exit /b 1

  start /wait cmd /c "C:\Program Files (x86)\Inno Setup 6\Compil32.exe" /cc install-mesa-dozen.iss || exit /b 1
  start /wait cmd /c "C:\Program Files (x86)\Inno Setup 6\Compil32.exe" /cc install-mesa-gl.iss || exit /b 1
  "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x64\signtool.exe" sign /a /n "Uplink Laboratories" /fd SHA256 /td SHA256 /tr http://timestamp.digicert.com ^
    Output\*.exe || exit /b 1
)
