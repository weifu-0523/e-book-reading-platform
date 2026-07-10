; 智阅 (ZhiYue) Windows installer script
; Requires Inno Setup 6+ (https://jrsoftware.org/isdl.php)
; Run after `flutter build windows --release` produces build/windows/x64/runner/Release/

#define MyAppName "智阅"
#define MyAppNameAscii "ZhiYue"
#define MyAppVersion "1.9.0-alpha"
#define MyAppPublisher "ZhiYue Open Source"
#define MyAppURL "https://gitee.com/weifu0523/e-book-reading-platform"
#define MyAppExeName "zhiyue.exe"

[Setup]
AppId={{8F8E7B5D-3D5B-4F8D-9C2A-2A4F5D5D5D5D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=zhiyue-setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter release bundle: zhiyue.exe + dll + data + assets
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; File associations: .epub and .pdf
[Registry]
; .epub
Root: HKA; Subkey: ".epub"; ValueType: string; ValueName: ""; ValueData: "ZhiYue.Book"; Flags: uninsdeletevalue
Root: HKA; Subkey: "ZhiYue.Book"; ValueType: string; ValueName: ""; ValueData: "智阅图书"; Flags: uninsdeletekey
Root: HKA; Subkey: "ZhiYue.Book\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "ZhiYue.Book\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""
; .pdf
Root: HKA; Subkey: ".pdf"; ValueType: string; ValueName: ""; ValueData: "ZhiYue.Pdf"; Flags: uninsdeletevalue
Root: HKA; Subkey: "ZhiYue.Pdf"; ValueType: string; ValueName: ""; ValueData: "智阅 PDF"; Flags: uninsdeletekey
Root: HKA; Subkey: "ZhiYue.Pdf\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "ZhiYue.Pdf\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Clean bundle files (data/Flutter assets etc.) but keep user data in %APPDATA%
Type: filesandordirs; Name: "{app}"
