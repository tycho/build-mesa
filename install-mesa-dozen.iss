#include "install-config.iss"
#include "version-dozen.iss"

#define MESA_DIST "mesa-dozen-" + MESA_VERSION

#define MyAppName "Mesa Dozen Driver"
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
Source: "mesa.prefix.vk\arm64\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\arm64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
Source: "mesa.prefix.vk\x86\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\x86\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
Source: "mesa.prefix.vk\x64\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\x64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
Source: "vkloader.prefix\arm64\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\loader\arm64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
Source: "vkloader.prefix\x86\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\loader\x86\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
Source: "vkloader.prefix\x64\bin\*"; Excludes: "*.pdb"; DestDir: "{app}\loader\x64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: driver
#ifdef ENABLE_DBGSYM
Source: "mesa.prefix.vk\arm64\bin\*.pdb"; DestDir: "{app}\arm64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
Source: "mesa.prefix.vk\x86\bin\*.pdb"; DestDir: "{app}\x86\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
Source: "mesa.prefix.vk\x64\bin\*.pdb"; DestDir: "{app}\x64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
Source: "vkloader.prefix\arm64\bin\*.pdb"; DestDir: "{app}\loader\arm64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
Source: "vkloader.prefix\x86\bin\*.pdb"; DestDir: "{app}\loader\x86\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
Source: "vkloader.prefix\x64\bin\*.pdb"; DestDir: "{app}\loader\x64\"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: dbgsym
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
    EnvAddPath(ExpandConstant('{app}') + '\loader\arm64');
    EnvAddPath(ExpandConstant('{app}') + '\loader\x64');
    EnvAddPath(ExpandConstant('{app}') + '\loader\x86');
	end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall
  then begin
	  EnvRemovePath(ExpandConstant('{app}') + '\loader\arm64');
	  EnvRemovePath(ExpandConstant('{app}') + '\loader\x64');
	  EnvRemovePath(ExpandConstant('{app}') + '\loader\x86');
	end;
end;

[Registry]
Root: HKLM32; Subkey: "SOFTWARE\Khronos\Vulkan\Drivers"; ValueType: dword; ValueName: "{app}\x86\dzn_icd.i686.json"; ValueData: 0x0; Flags: uninsdeletevalue
Root: HKLM64; Subkey: "SOFTWARE\Khronos\Vulkan\Drivers"; ValueType: dword; ValueName: "{app}\x64\dzn_icd.x86_64.json"; ValueData: 0x0; Flags: uninsdeletevalue
Root: HKLM64; Subkey: "SOFTWARE\Khronos\Vulkan\Drivers"; ValueType: dword; ValueName: "{app}\arm64\dzn_icd.armv8.json"; ValueData: 0x0; Flags: uninsdeletevalue
Root: HKLM64; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: string; ValueName: "MesaDozenSDKRoot"; ValueData: "{app}\"; Flags: uninsdeletevalue
Root: HKLM32; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: string; ValueName: "MesaDozenSDKRoot"; ValueData: "{app}\"; Flags: uninsdeletevalue

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
