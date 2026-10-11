; Inno Setup script. Build: iscc /DAppVersion=1.2.3 installer\windows.iss
; AppId is fixed on purpose: a newer Setup.exe finds the existing install and upgrades it in place.
; Saves live in %APPDATA%\ToTAK, outside the install folder, so upgrades and uninstalls never touch them.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{8F3C2E1A-5B7D-4C9E-A1F0-7D2B6E4C9A31}
AppName=Tombs of the Ancient Kings
AppVersion={#AppVersion}
AppPublisher=ToTAK
AppPublisherURL=https://github.com/AWeebTaku/ToTAK
DefaultDirName={autopf}\ToTAK
DefaultGroupName=ToTAK
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
CloseApplications=yes
UninstallDisplayIcon={app}\icon.ico
SetupIconFile=..\assets\icon.ico
OutputDir=..\dist
OutputBaseFilename=ToTAK-{#AppVersion}-windows-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "..\build\windows\ToTAK.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Tombs of the Ancient Kings"; Filename: "{app}\ToTAK.exe"; IconFilename: "{app}\icon.ico"
Name: "{autodesktop}\Tombs of the Ancient Kings"; Filename: "{app}\ToTAK.exe"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\ToTAK.exe"; Description: "Launch the game"; Flags: nowait postinstall skipifsilent
