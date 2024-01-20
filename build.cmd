@echo off
setlocal enabledelayedexpansion

set MESA_VERSION=24.0.0-rc2
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

set VS160COMNTOOLS=!VS!\Common7\Tools\
set VS170COMNTOOLS=!VS!\Common7\Tools\

rem *** download sources ***

if not exist mesa.src (
echo Downloading mesa
curl -sfL https://archive.mesa3d.org/mesa-%MESA_VERSION%.tar.xz ^
  | %SZIP% x -bb0 -txz -si -so ^
  | %SZIP% x -bb0 -ttar -si -aoa 1>nul 2>nul
move mesa-%MESA_VERSION% mesa.src
git apply -p0 --directory=mesa.src mesa.patch || exit /b 1
)

echo Downloading win_flex_bison
if not exist winflexbison (
  mkdir winflexbison
  pushd winflexbison
  curl -sfL -o win_flex_bison.zip https://github.com/lexxmark/winflexbison/releases/download/v2.5.25/win_flex_bison-2.5.25.zip || exit /b 1
  %SZIP% x -bb0 -y win_flex_bison.zip 1>nul 2>nul || exit /b 1
  del win_flex_bison.zip 1>nul 2>nul
  popd
)

del "@PaxHeader" "HEAD" "pax_global_header" 1>nul 2>nul

set LINK=version.lib


rem x86 build

call "!VS!\Common7\Tools\vsdevcmd.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" x86 %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

rd /s /q mesa.build.x86 1>nul 2>nul
meson setup ^
  mesa.build.x86 ^
  mesa.src ^
  --cross-file=cross-x86.txt ^
  --prefix="%CD%\mesa-d3d12\x86" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12 ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dvulkan-drivers=microsoft-experimental ^
  -Dvulkan-icd-dir="%CD%\mesa-d3d12\x86\bin" ^
  -Dopengl=false ^
  -Dgles1=disabled ^
  -Dgles2=disabled || exit /b 1
ninja -C mesa.build.x86 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x86\dxil.dll" "%CD%\mesa-d3d12\x86\bin\"


rem arm64 build

call "!VS!\Common7\Tools\vsdevcmd.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" x64_arm64 %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

rd /s /q mesa.build.arm64 1>nul 2>nul
meson setup ^
  mesa.build.arm64 ^
  mesa.src ^
  --cross-file=cross-arm64.txt ^
  --prefix="%CD%\mesa-d3d12\arm64" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12 ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dvulkan-drivers=microsoft-experimental ^
  -Dvulkan-icd-dir="%CD%\mesa-d3d12\arm64\bin" ^
  -Dopengl=false ^
  -Dgles1=disabled ^
  -Dgles2=disabled || exit /b 1
ninja -C mesa.build.arm64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\arm64\dxil.dll" "%CD%\mesa-d3d12\arm64\bin\"


rem x64 build

call "!VS!\Common7\Tools\vsdevcmd.bat" /clean_env || exit /b 1
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" x64 %WINSDK_VER% || exit /b 1
set PATH=%CD%\winflexbison;%PATH%

rd /s /q mesa.build.x64 1>nul 2>nul
meson setup ^
  mesa.build.x64 ^
  mesa.src ^
  --cross-file=cross-x64.txt ^
  --prefix="%CD%\mesa-d3d12\x64" ^
  --default-library=static ^
  -Dmin-windows-version=10 ^
  -Dbuildtype=release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Dllvm=disabled ^
  -Dplatforms=windows ^
  -Dosmesa=false ^
  -Dgallium-drivers=d3d12 ^
  -Dspirv-to-dxil=false ^
  -Dshared-glapi=enabled ^
  -Dvulkan-drivers=microsoft-experimental ^
  -Dvulkan-icd-dir="%CD%\mesa-d3d12\x64\bin" ^
  -Dopengl=false ^
  -Dgles1=disabled ^
  -Dgles2=disabled || exit /b 1
ninja -C mesa.build.x64 install || exit /b 1
copy "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\dxil.dll" "%CD%\mesa-d3d12\x64\bin\"

python patch-icds.py
start /wait cmd /c "C:\Program Files (x86)\Inno Setup 6\Compil32.exe" /cc install-mesa-dozen-vk.iss
"C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" sign /a /n "Uplink Laboratories" /fd SHA256 /td SHA256 /tr http://timestamp.digicert.com Output\*exe