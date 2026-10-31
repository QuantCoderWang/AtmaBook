[Setup]
AppName=AtmaBook
AppVersion=1.0.0
AppPublisher=WangYuwen
DefaultDirName={autopf}\AtmaBook
DefaultGroupName=AtmaBook
UninstallDisplayIcon={app}\atma_book.exe
OutputDir=build\installer
OutputBaseFilename=AtmaBook-Setup-1.0.0
SetupIconFile=assets\icon\app_icon.ico
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Messages]
WelcomeLabel1=欢迎使用AtmaBook安装向导，这是目前第一款完全本地化攻略制作+地理照片应用。
WelcomeLabel2=这将把AtmaBook安装到你的电脑，AtmaBook完全在本地运行，无需网络即可实现本地化的攻略、照片分享。

FinishedLabel=AtmaBook已被成功安装到你的电脑。%n%n点击"完成"运行AtmaBook。

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\AtmaBook"; Filename: "{app}\atma_book.exe"
Name: "{group}\卸载 AtmaBook"; Filename: "{uninstallexe}"
Name: "{autodesktop}\AtmaBook"; Filename: "{app}\atma_book.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\atma_book.exe"; Description: "立即运行 AtmaBook"; Flags: nowait postinstall skipifsilent
