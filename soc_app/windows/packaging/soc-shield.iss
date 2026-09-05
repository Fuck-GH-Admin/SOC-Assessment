; 碳盾 · SOC-Shield — Windows 安装包脚本（Inno Setup 6）
; 由 GitHub Actions 的 windows runner 在 CI 中调用：
;   iscc /DAppVersion=<x.y.z> windows/packaging/soc-shield.iss
; 产物: Output/soc-shield-setup-<version>.exe
; 前置: flutter build windows --release 已完成，bundle 位于
;       build/windows/x64/runner/Release/

#define AppName "碳盾 · SOC-Shield"
#define AppNameEn "SOC-Shield"
#define AppPublisher "SOC-Shield"
#define AppExe "soc_app.exe"
#define AppGuide "https://github.com/Fuck-GH-Admin/SOC-Assessment"

#ifndef AppVersion
#define AppVersion "0.0.0"
#endif

[Setup]
AppId={{8A6E2B54-4C0D-5A11-9A3E-SOCSHIELD00}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppGuide}
AppSupportURL={#AppGuide}/issues
DefaultDirName={autopf}\{#AppNameEn}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=soc-shield-setup-{#AppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExe}

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Release 目录的全部运行时文件（exe/dll/data）
Source: "..\..\build\windows\x64\runner\Release\*"; \
  DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 卸载仅清理安装目录；用户数据（文档目录下的数据库与报告）保留
Type: filesandordirs; Name: "{app}\data"
