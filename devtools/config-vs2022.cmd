@echo off
setlocal enabledelayedexpansion

cd /d %~dp0\..

set PATH=%CD%\winflexbison;%PATH%

set __VSCMD_ARG_NO_LOGO=1
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
if "!VS!" equ "" (
  echo ERROR: Visual Studio installation not found
  exit /b 1
)

call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" /clean_env >nul 2>nul
call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" x64 10.0.26100.0 || exit /b 1

meson setup ^
	mesa.vs.gl.x64 ^
	mesa.src ^
	--reconfigure ^
	--backend vs2022 ^
	--cross-file=cross-x64.txt ^
	--prefix="%CD%\mesa.prefix.gl\x64" ^
	--default-library=static ^
	-Dmin-windows-version=10 ^
	-Dllvm=disabled ^
	-Dplatforms=windows ^
	-Dgallium-drivers=d3d12,zink ^
	-Dspirv-to-dxil=false ^
	-Dshared-glapi=enabled ^
	-Dopengl=true ^
	-Dgles1=enabled ^
	-Dgles2=enabled ^
	-Degl=enabled || exit /b 1

meson setup ^
	mesa.vs.vk.x64 ^
	mesa.src ^
	--reconfigure ^
	--backend vs2022 ^
	--cross-file=cross-x64.txt ^
	--prefix="%CD%\mesa.prefix.vk\x64" ^
	--default-library=static ^
	-Dmin-windows-version=10 ^
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
