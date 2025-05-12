; CI-friendly Inno Setup Script
; Adapted for use in automated build environments

#define MyAppName "NETxTEN"
#define MyAppVersion "1.0"
#define MyAppPublisher "NETxTEN"
#define MyAppURL "https://www.example.com/"
#define MyAppExeName "netxten.exe"

[Setup]
AppId={{40E3747D-3042-497A-A3DA-A9DB18474498}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
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
Source: "build/windows/x64/runner/Release/{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avcodec.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avcodec-61.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avdevice.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avdevice-61.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avfilter.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avfilter-10.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avformat.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avformat-61.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avutil.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/avutil-59.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/blabla.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/blabla.exp"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/blabla.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/libliquid.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/postproc.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/postproc-58.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/sample_library.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/screen_retriever_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/swresample.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/swresample-5.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/swscale.lib"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/swscale-8.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build/windows/x64/runner/Release/data/*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x64\Microsoft.VC143.CRT\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x64\Microsoft.VC143.CRT\msvcp140_1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x64\Microsoft.VC143.CRT\msvcp140_2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x64\Microsoft.VC143.CRT\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC\14.42.34433\x64\Microsoft.VC143.CRT\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent 