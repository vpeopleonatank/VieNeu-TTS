; Compiled by build_installer.ps1 (defines AppVersion, StageDir, RootDir).
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6E0C5F7A-3B2D-4C58-9A1E-5B7D0E4F1A21}
AppName=VieNeu-TTS
AppVersion={#AppVersion}
AppPublisher=VieNeu-TTS
; Per-user install: app + user data stay writable without admin rights.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\VieNeu-TTS
DefaultGroupName=VieNeu-TTS
DisableProgramGroupPage=yes
LicenseFile={#StageDir}\LICENSE
OutputDir=dist
OutputBaseFilename=VieNeu-TTS-Setup-{#AppVersion}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Models are ~1 GB of already-compressed ONNX: store them, compress only code/wheels.
Compression=lzma2/fast
SolidCompression=no
DiskSpanning=no
UninstallDisplayName=VieNeu-TTS
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#StageDir}\python\*";   DestDir: "{app}\python";   Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#StageDir}\app\*";      DestDir: "{app}\app";      Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#StageDir}\hf_cache\*"; DestDir: "{app}\hf_cache"; Flags: recursesubdirs createallsubdirs ignoreversion nocompression
Source: "{#StageDir}\VieNeu-TTS.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\LICENSE";    DestDir: "{app}";          Flags: ignoreversion

[Icons]
Name: "{group}\VieNeu-TTS";           Filename: "{app}\VieNeu-TTS.cmd"; WorkingDir: "{app}"
Name: "{group}\Uninstall VieNeu-TTS"; Filename: "{uninstallexe}"
Name: "{autodesktop}\VieNeu-TTS";     Filename: "{app}\VieNeu-TTS.cmd"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\VieNeu-TTS.cmd"; Description: "Launch VieNeu-TTS"; Flags: postinstall nowait skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\app\merged_models_cache"
Type: filesandordirs; Name: "{app}\python\Lib\site-packages\__pycache__"
