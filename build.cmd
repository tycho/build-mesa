@echo off
setlocal enabledelayedexpansion

set MESA_BRANCH=24.0
set VKLOADER_BRANCH=vulkan-sdk-1.3.275
set WINSDK_VER=10.0.22621.0

set PATH=%CD%\winflexbison;%PATH%

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
  pip install mako
  python -c "import mako" 2>nul || (
    echo ERROR: "mako" module not found for python
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
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
if "!VS!" equ "" (
	echo ERROR: Visual Studio installation not found
	exit /b 1
)  

rem This is not set by vsdevcmd for whatever reason, which breaks our clean_env invocation, so set it now.
set VS170COMNTOOLS=!VS!\Common7\Tools\

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
cd mesa.src

rem Git options that help with Windows git clones
git config core.ignoreCase true
git config core.filemode false

git checkout -t origin/%MESA_BRANCH% || git checkout %MESA_BRANCH%
git pull
cd ..

if not exist vkloader.src (
  echo Cloning Vulkan loader from git
  git clone https://github.com/KhronosGroup/Vulkan-Loader.git vkloader.src
)
cd vkloader.src

rem Git options that help with Windows git clones
git config core.ignoreCase true
git config core.filemode false

git checkout -t origin/%VKLOADER_BRANCH% || git checkout %VKLOADER_BRANCH%
git pull
cd ..

rem remove old install prefixes

rd /s/q .\mesa.prefix.gl
rd /s/q .\mesa.prefix.vk
rd /s/q .\vkloader.prefix


rem x86 build

call "!VS!\Common7\Tools\vsdevcmd.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" x86 %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

rd /s /q mesa.build.vk.x86 1>nul 2>nul
meson setup ^
  mesa.build.vk.x86 ^
  mesa.src ^
  --cross-file=cross-x86.txt ^
  --prefix="%CD%\mesa.prefix.vk\x86" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dgallium-drivers="" ^
  -Dvulkan-drivers=microsoft-experimental ^
  -Dvulkan-icd-dir="%CD%\mesa.prefix.vk\x86\bin" ^
  -Dopengl=false ^
  -Dgles1=disabled ^
  -Dgles2=disabled ^
  -Degl=disabled || exit /b 1
ninja -C mesa.build.vk.x86 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x86\dxil.dll" "%CD%\mesa.prefix.vk\x86\bin\"

rd /s /q mesa.build.gl.x86 1>nul 2>nul
meson setup ^
  mesa.build.gl.x86 ^
  mesa.src ^
  --cross-file=cross-x86.txt ^
  --prefix="%CD%\mesa.prefix.gl\x86" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12,zink ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dopengl=true ^
  -Dgles1=enabled ^
  -Dgles2=enabled ^
  -Degl=enabled || exit /b 1
ninja -C mesa.build.gl.x86 install || exit /b 1

cmake -G Ninja ^
  -S vkloader.src ^
  -B vkloader.build.x86 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_INSTALL_PREFIX="%CD%\vkloader.prefix\x86" ^
  -DUPDATE_DEPS=ON
cmake --build vkloader.build.x86
cmake --install vkloader.build.x86


rem arm64 build

call "!VS!\Common7\Tools\vsdevcmd.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" x64_arm64 %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

rd /s /q mesa.build.vk.arm64 1>nul 2>nul
meson setup ^
  mesa.build.vk.arm64 ^
  mesa.src ^
  --cross-file=cross-arm64.txt ^
  --prefix="%CD%\mesa.prefix.vk\arm64" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dgallium-drivers="" ^
  -Dvulkan-drivers=microsoft-experimental ^
  -Dvulkan-icd-dir="%CD%\mesa.prefix.vk\arm64\bin" ^
  -Dopengl=false ^
  -Dgles1=disabled ^
  -Dgles2=disabled ^
  -Degl=disabled || exit /b 1
ninja -C mesa.build.vk.arm64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\arm64\dxil.dll" "%CD%\mesa.prefix.vk\arm64\bin\"

rd /s /q mesa.build.gl.arm64 1>nul 2>nul
meson setup ^
  mesa.build.gl.arm64 ^
  mesa.src ^
  --cross-file=cross-arm64.txt ^
  --prefix="%CD%\mesa.prefix.gl\arm64" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12,zink ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dopengl=true ^
  -Dgles1=enabled ^
  -Dgles2=enabled ^
  -Degl=enabled || exit /b 1
ninja -C mesa.build.gl.arm64 install || exit /b 1

cmake -G Ninja ^
  -S vkloader.src ^
  -B vkloader.build.arm64 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_INSTALL_PREFIX="%CD%\vkloader.prefix\arm64" ^
  -DUPDATE_DEPS=ON
cmake --build vkloader.build.arm64
cmake --install vkloader.build.arm64


rem x64 build

call "!VS!\Common7\Tools\vsdevcmd.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" x64 %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

rd /s /q mesa.build.vk.x64 1>nul 2>nul
meson setup ^
  mesa.build.vk.x64 ^
  mesa.src ^
  --cross-file=cross-x64.txt ^
  --prefix="%CD%\mesa.prefix.vk\x64" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dgallium-drivers="" ^
  -Dvulkan-drivers=microsoft-experimental ^
  -Dvulkan-icd-dir="%CD%\mesa.prefix.vk\x64\bin" ^
  -Dopengl=false ^
  -Dgles1=disabled ^
  -Dgles2=disabled ^
  -Degl=disabled || exit /b 1
ninja -C mesa.build.vk.x64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\%WINSDK_VER%\x64\dxil.dll" "%CD%\mesa.prefix.vk\x64\bin\"

rd /s /q mesa.build.gl.x64 1>nul 2>nul
meson setup ^
  mesa.build.gl.x64 ^
  mesa.src ^
  --cross-file=cross-x64.txt ^
  --prefix="%CD%\mesa.prefix.gl\x64" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12,zink ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dopengl=true ^
  -Dgles1=enabled ^
  -Dgles2=enabled ^
  -Degl=enabled || exit /b 1
ninja -C mesa.build.gl.x64 install || exit /b 1

cmake -G Ninja ^
  -S vkloader.src ^
  -B vkloader.build.x64 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_INSTALL_PREFIX="%CD%\vkloader.prefix\x64" ^
  -DUPDATE_DEPS=ON
cmake --build vkloader.build.x64
cmake --install vkloader.build.x64


rem build installer

python gen-version.py || exit /b 1
python patch-icds.py || exit /b 1

"C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" sign /a /n "Uplink Laboratories" /fd SHA256 /td SHA256 /tr http://timestamp.digicert.com ^
  mesa.prefix.vk\x86\bin\*.dll mesa.prefix.vk\x86\bin\*.exe vkloader.prefix\x86\bin\*.dll ^
  mesa.prefix.vk\x64\bin\*.dll mesa.prefix.vk\x64\bin\*.exe vkloader.prefix\x64\bin\*.dll ^
  mesa.prefix.vk\arm64\bin\*.dll mesa.prefix.vk\arm64\bin\*.exe vkloader.prefix\arm64\bin\*.dll ^
  mesa.prefix.gl\x86\bin\*.dll ^
  mesa.prefix.gl\x64\bin\*.dll ^
  mesa.prefix.gl\arm64\bin\*.dll

start /wait cmd /c "C:\Program Files (x86)\Inno Setup 6\Compil32.exe" /cc install-mesa-dozen.iss || exit /b 1
start /wait cmd /c "C:\Program Files (x86)\Inno Setup 6\Compil32.exe" /cc install-mesa-gl.iss || exit /b 1
"C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" sign /a /n "Uplink Laboratories" /fd SHA256 /td SHA256 /tr http://timestamp.digicert.com ^
  Output\*.exe
