#include "install-config.iss"
#include "version-gl.iss"

#define MESA_DIST "mesa-gl-" + MESA_VERSION

#define MyAppName "Mesa OpenGL"
#define MyAppVersion MESA_VERSION
#define MyAppPublisher "Uplink Laboratories, LLC"
#define MyAppURL "https://gitlab.freedesktop.org/mesa/mesa"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={#INSTALLER_UUID}
AppName={#MyAppName}
AppVersion={#MESA_VERSION}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName=C:\Mesa\{#MESA_DIST}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Uncomment the following line to run in non administrative install mode (install for current user only.)
;PrivilegesRequired=lowest
#ifdef ENABLE_DBGSYM
OutputBaseFilename=setup-{#MESA_DIST}-dbgsym
#else
OutputBaseFilename=setup-{#MESA_DIST}
#endif
Compression=lzma2/max
SolidCompression=yes
WizardStyle=classic
Uninstallable=yes
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Components]
Name: "driver"; Description: "Driver"; Types: full compact custom; Flags: fixed
#ifdef ENABLE_DBGSYM
Name: "dbgsym"; Description: "Debug Symbols"; Types: full
#endif

[Files]
Source: "mesa.prefix.gl\arm64\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\arm64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
Source: "mesa.prefix.gl\x86\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\x86\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
Source: "mesa.prefix.gl\x64\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\x64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
#ifdef ENABLE_DBGSYM
Source: "mesa.prefix.gl\arm64\bin\*.pdb"; DestDir: "{app}\arm64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
Source: "mesa.prefix.gl\x86\bin\*.pdb"; DestDir: "{app}\x86\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
Source: "mesa.prefix.gl\x64\bin\*.pdb"; DestDir: "{app}\x64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
#endif

[Code]
const EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

procedure EnvAddPath(Path: string);
var
    Paths: string;
begin
    { Retrieve current path (use empty string if entry not exists) }
    if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)
    then Paths := '';

    { Skip if string already found in path }
    if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then exit;

    { App string to the end of the path variable }
    Paths := Paths + ';'+ Path +';'

    { Overwrite (or create if missing) path environment variable }
    if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)
    then Log(Format('The [%s] added to PATH: [%s]', [Path, Paths]))
    else Log(Format('Error while adding the [%s] to PATH: [%s]', [Path, Paths]));
end;

procedure EnvRemovePath(Path: string);
var
    Paths: string;
    P: Integer;
begin
    { Skip if registry entry not exists }
    if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
        exit;

    { Skip if string not found in path }
    P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
    if P = 0 then exit;

    { Update path variable }
    Delete(Paths, P - 1, Length(Path) + 1);

    { Overwrite path environment variable }
    if RegWriteStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths)
    then Log(Format('The [%s] removed from PATH: [%s]', [Path, Paths]))
    else Log(Format('Error while removing the [%s] from PATH: [%s]', [Path, Paths]));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall 
   then begin 
    EnvAddPath(ExpandConstant('{app}') + '\arm64');
    EnvAddPath(ExpandConstant('{app}') + '\x64');
    EnvAddPath(ExpandConstant('{app}') + '\x86');
	end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall
  then begin 
	  EnvRemovePath(ExpandConstant('{app}') + '\arm64');
	  EnvRemovePath(ExpandConstant('{app}') + '\x64');
	  EnvRemovePath(ExpandConstant('{app}') + '\x86');
	end;
end;

[Registry]
Root: HKLM32; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: string; ValueName: "DLL"; ValueData: "libgallium_wgl.dll"; Flags: uninsdeletevalue
Root: HKLM32; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: dword; ValueName: "DriverVersion"; ValueData: 0x1; Flags: uninsdeletevalue
Root: HKLM32; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: dword; ValueName: "Flags"; ValueData: 0x1; Flags: uninsdeletevalue
Root: HKLM32; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: dword; ValueName: "Version"; ValueData: 0x2; Flags: uninsdeletevalue

Root: HKLM64; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: string; ValueName: "DLL"; ValueData: "libgallium_wgl.dll"; Flags: uninsdeletevalue
Root: HKLM64; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: dword; ValueName: "DriverVersion"; ValueData: 0x1; Flags: uninsdeletevalue
Root: HKLM64; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: dword; ValueName: "Flags"; ValueData: 0x1; Flags: uninsdeletevalue
Root: HKLM64; Subkey: "SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers\MSOGL"; ValueType: dword; ValueName: "Version"; ValueData: 0x2; Flags: uninsdeletevalue

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
