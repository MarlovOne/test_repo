; CI-friendly Inno Setup Script
; Adapted for use in automated build environments

#define MyAppName "NETxTEN"
#define MyAppVersion "1.0"
#define MyAppPublisher "NETxTEN"
#define MyAppURL "https://www.example.com/"
#define MyAppExeName "test_repo.exe"

[Setup]
AppId={{40E3747D-3042-497A-A3DA-A9DB18474498}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#GetEnv("OUTPUT_DIR")}
OutputBaseFilename=netxten-windows-x86_64
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#GetEnv("LIB_PATH")}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avcodec.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avcodec-61.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avdevice.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avdevice-61.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avfilter.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avfilter-10.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avformat.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avformat-61.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avutil.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\avutil-59.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\blabla.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\blabla.exp"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\blabla.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\libliquid.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\postproc.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\postproc-58.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\sample_library.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\swresample.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\swresample-5.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\swscale.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\swscale-8.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("LIB_PATH")}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#GetEnv("VCToolsRedistDir")}\x64\Microsoft.VC143.CRT\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("VCToolsRedistDir")}\x64\Microsoft.VC143.CRT\msvcp140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("VCToolsRedistDir")}\x64\Microsoft.VC143.CRT\msvcp140_2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("VCToolsRedistDir")}\x64\Microsoft.VC143.CRT\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#GetEnv("VCToolsRedistDir")}\x64\Microsoft.VC143.CRT\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent 