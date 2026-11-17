; Inno Setup script. Built by build.ps1, which fills stage\ first.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6E1B9B3C-5A0D-4C57-9F0E-3B7C1D2A8F41}
AppName=MuScriptor
AppVersion={#AppVersion}
AppPublisher=Kyutai x Mirelo
AppPublisherURL=https://github.com/muscriptor/muscriptor
; Per-user install: no admin prompt, and the venv/caches stay writable.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\MuScriptor
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=MuScriptor-{#AppVersion}-setup-x64
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes
UninstallDisplayName=MuScriptor

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
Name: "addtopath"; Description: "Add the `muscriptor` command to PATH (for the CLI)"; Flags: unchecked

[Files]
Source: "stage\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "setup.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "prewarm.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "launcher.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "muscriptor.cmd"; DestDir: "{app}\bin"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\MuScriptor"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\launcher.ps1"""; WorkingDir: "{app}"
Name: "{autodesktop}\MuScriptor"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\launcher.ps1"""; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; \
  ValueData: "{olddata};{app}\bin"; Tasks: addtopath; Check: NeedsAddPath(ExpandConstant('{app}\bin'))

[UninstallDelete]
; venv, python, caches and downloaded weights are created after install.
Type: filesandordirs; Name: "{app}"

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Uppercase(Param) + ';', ';' + Uppercase(OrigPath) + ';') = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Downloads Python, PyTorch and the soundfonts; the console shows progress.
    if not Exec(ExpandConstant('{cmd}'), ExpandConstant('/C ""{app}\setup.cmd""'), ExpandConstant('{app}'),
                SW_SHOW, ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
      MsgBox('Downloading the dependencies failed. Check your internet connection, ' +
             'then run "' + ExpandConstant('{app}\setup.cmd') + '" again.', mbError, MB_OK);
  end;
end;
