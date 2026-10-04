unit config_unit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, Process, LCLType, StrUtils, IniFiles;

type

  { TConfigForm }

  TConfigForm = class(TForm)
    OpenDialog1: TOpenDialog;
    ProfileBox: TComboBox;
    Label5: TLabel;
    ProxyEdit: TEdit;
    Label4: TLabel;
    SaveDialog1: TSaveDialog;
    ServerBox: TComboBox;
    Label3: TLabel;
    OkBtn: TBitBtn;
    CloseBtn: TBitBtn;
    LoginEdit: TEdit;
    PasswordEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    LoadBtn: TSpeedButton;
    SaveBtn: TSpeedButton;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure LoadBtnClick(Sender: TObject);
    procedure OkBtnClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ProfileBoxChange(Sender: TObject);
    procedure ReadProfile(Profile: string);
    procedure SaveBtnClick(Sender: TObject);
    procedure StartProcess(command: string);
    procedure ReadActiveProfile;
    procedure WriteDialogsInitDir;
    procedure ReadDialogsInitDir;

  private
  var
    OtherServerURL: string;

  public

  end;

  //Ресурсы перевода
resourcestring
  SNoBackup = 'The archive does not correspond to WDGUI!';
  SLoad = 'Decrypt and Load';
  SSave = 'Encrypt and Save';
  SEncryptPassword = 'Enter encryption password:';
  SDecryptPassword = 'The database will be replaced. Enter decryption password:';

var
  ConfigForm: TConfigForm;

implementation

uses unit1;

  {$R *.lfm}

  { TConfigForm }

//StartCommand - общая процедура запуска команд (синхронная)
procedure TConfigForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    ExProcess.Options := [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Чтение InitialDir для OpenDialog и SaveDialog
procedure TConfigForm.ReadDialogsInitDir;
begin
  with TIniFile.Create(GetUserDir + '.config/wdgui/wdgui.conf') do
  try
    OpenDialog1.InitialDir := ReadString('Settings', 'OpenDialog', GetUserDir);
    SaveDialog1.InitialDir := ReadString('Settings', 'SaveDialog', GetUserDir);
  finally
    Free;
  end;
end;

//Чтение InitialDir для OpenDialog и SaveDialog
procedure TConfigForm.WriteDialogsInitDir;
begin
  with TIniFile.Create(GetUserDir + '.config/wdgui/wdgui.conf') do
  try
    WriteString('Settings', 'OpenDialog', OpenDialog1.InitialDir);
    WriteString('Settings', 'SaveDialog', SaveDialog1.InitialDir);
  finally
    Free;
  end;
end;

//Читаем имя активного профиля
procedure TConfigForm.ReadActiveProfile;
begin
  if FileExists(GetUserDir + '.config/wdgui/wdgui.conf') then
    with TIniFile.Create(GetUserDir + '.config/wdgui/wdgui.conf') do
    try
      ProfileBox.Text := ReadString('Settings', 'Profile', 'OTHER');
      ReadProfile(ProfileBox.Text);

      if ProfileBox.Text = 'OTHER' then ServerBox.Enabled := True;
    finally
      Free;
    end;
end;

function EscapeParamForBash(const S: string): string;
begin
  // Заменяем каждую одиночную кавычку ' на последовательность '\'',
  // которая закрывает строку, вставляет экранированную кавычку и открывает строку заново.
  Result := '''' + StringReplace(S, '''', '''\''''', [rfReplaceAll]) + '''';
end;

//Валидация загружаемого архива (БД из *.tar.gz)
function IsBackup(input, password: string): boolean;
var
  ExProcess: TProcess;
  EscapedPass, EscapedFile: string;
begin
  Result := False; // По умолчанию считаем, что валидация не прошла
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');

    // Очищаем параметры через нашу функцию (без двойных кавычек вокруг!)
    EscapedPass := EscapeParamForBash(password);
    EscapedFile := EscapeParamForBash(input);

    // Безопасная команда. В конце проверяем код возврата всей цепочки через ${PIPESTATUS[2]}
    // PIPESTATUS[0] - gpg, PIPESTATUS[1] - tar, PIPESTATUS[2] - grep
    ExProcess.Parameters.Add('gpg --batch --yes --passphrase ' + EscapedPass +
      ' --decrypt ' + EscapedFile + ' 2>/dev/null | tar -tf - 2>/dev/null | grep -q "./wdgui.conf"; exit ${PIPESTATUS[2]}');

    // Убираем poUsePipes, так как мы больше не читаем поток вывода в Pascal,
    // а полагаемся на точный код возврата от самого grep/bash.
    ExProcess.Options := [poWaitOnExit];
    ExProcess.Execute;

    // Если grep нашёл файл, код выхода (ExitStatus) всей цепочки команд будет равен 0
    if ExProcess.ExitStatus = 0 then
      Result := True;

  finally
    ExProcess.Free;
  end;
end;

//Чтение выбранного профиля
procedure TConfigForm.ReadProfile(Profile: string);
var
  password: string;
begin
  //Читаем рабочий профиль в rclone.conf
  if FileExists(GetUserDir + '.config/wdgui/profiles/' + Profile) then
    with TIniFile.Create(GetUserDir + '.config/wdgui/profiles/' + Profile) do
    try
      ServerBox.Text := Trim(ReadString('server', 'url', ''));
      LoginEdit.Text := Trim(ReadString('server', 'user', ''));

      //password
      if RunCommand('rclone', ['reveal', Trim(ReadString('server', 'pass', ''))],
        password) then
        PasswordEdit.Text := Trim(password);

      //proxy
      ProxyEdit.Text := Trim(ReadString('server', 'override.http_proxy', ''));

      //Запоминаем несуществующий в списках url для профиля OTHER (для перемотки)
      if ProfileBox.Text = 'OTHER' then OtherServerURL := ServerBox.Text;
    finally
      Free;
    end
  else
  begin
    ServerBox.Text := '';
    LoginEdit.Clear;
    PasswordEdit.Clear;
    ProxyEdit.Clear;
  end;
end;

//Сохранить
procedure TConfigForm.SaveBtnClick(Sender: TObject);
var
  password: string;
  FullFileName: string;
begin
  if not FileExists(IncludeTrailingPathDelimiter(GetUserDir) + '.config/wdgui/wdgui.conf') then Exit;

  password := '';
  repeat
    if not InputQuery(SSave, SEncryptPassword, password) then Exit;
  until password <> '';

  SaveDialog1.DefaultExt := '.tar.gpg';
  SaveDialog1.FileName := 'wdgui-' + FormatDateTime('dd-mm-yyyy-hh-nn-ss', Now);

  if SaveDialog1.Execute then
  begin
    Application.ProcessMessages;

    FullFileName := SaveDialog1.FileName;
    if not EndsText('.tar.gpg', FullFileName) then
    begin
      if EndsText('.gpg', FullFileName) then
        FullFileName := ChangeFileExt(FullFileName, '.tar.gpg')
      else
        FullFileName := FullFileName + '.tar.gpg';
    end;

    // Собираем команду, безопасно экранируя и пароль, и имя файла под правила bash
    StartProcess('cd ~/.config/wdgui && tar -cf - . | gpg --cipher-algo AES256 --batch --yes --passphrase '
      + EscapeParamForBash(password) + ' -c -o ' + EscapeParamForBash(FullFileName));
  end;
end;

//Запись настроек в профильный файл и рабочий rclone.conf
procedure TConfigForm.OkBtnClick(Sender: TObject);
var
  S: TStringList;
  password: string;
begin
  if (Trim(ServerBox.Text) = '') or (Trim(LoginEdit.Text) = '') or
    (Trim(PasswordEdit.Text) = '') then
  begin
    MessageDlg(SNoData, mtWarning, [mbOK], 0);
    ModalResult := 0;
    Exit;
  end;

  //Обновить правую панель, если подключение состоялось
  left_panel := False;

  //Пишем активный профиль в ~/.config/wdgui/wdgui.conf
  with TIniFile.Create(GetUserDir + '.config/wdgui/wdgui.conf') do
  try
    WriteString('Settings', 'Profile', ProfileBox.Text);
  finally
    Free;
  end;

  //Делаем новый ~/.config/wdgui/profiles/ProfileBox.Text и сохраняем
  try
    S := TStringList.Create;
    S.Add('[server]');

    S.Add('type = webdav');
    S.Add('url = ' + Trim(ServerBox.Text));

    S.Add('vendor = rclone');
    S.Add('user = ' + Trim(LoginEdit.Text));

    //password
    if RunCommand('rclone', ['obscure', PasswordEdit.Text], password) then
      S.Add('pass = ' + Trim(password));

    //proxy
    if ProxyEdit.Text <> '' then
      S.Add('override.http_proxy = ' + Trim(ProxyEdit.Text));

    S.SaveToFile(GetUserDir + '.config/wdgui/profiles/' + ProfileBox.Text);
    S.SaveToFile(GetUserDir + '.config/wdgui/rclone.conf');

    //Пробуем открыть корень облака
    MainForm.GroupBox2.Caption := '/';
    MainForm.StartProcess('pkill -x rclone');
    MainForm.StartLS;
  finally
    S.Free;
  end;
end;

procedure TConfigForm.FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    ConfigForm.Close;
end;

//Загрузить
procedure TConfigForm.LoadBtnClick(Sender: TObject);
var
  password: string;
  EscapedPass, EscapedFile: string;
begin
  password := '';

  // Продолжаем спрашивать пароль
  repeat
    if not InputQuery(SLoad, SDecryptPassword, password) then Exit;
  until password <> '';

  if OpenDialog1.Execute then
  begin
    // Проверка валидности загружаемого архива
    Application.ProcessMessages;
    if not IsBackup(OpenDialog1.FileName, password) then
    begin
      MessageDlg(SNoBackup, mtWarning, [mbOK], 0);
      Exit;
    end;

    Application.ProcessMessages;

    // Готовим безопасные параметры для bash (без двойных кавычек!)
    EscapedPass := EscapeParamForBash(password);
    EscapedFile := EscapeParamForBash(OpenDialog1.FileName);

    // Расшифровка и распаковка
    // Заменили ";" на "&&", чтобы rm -rf выполнялся строго после успешного перехода в папку
    StartProcess('cd ~/.config/wdgui/ && rm -rf ./* && gpg --batch --yes --passphrase ' +
      EscapedPass + ' -d ' + EscapedFile + ' | tar -xf -');

    ReadActiveProfile;
  end;
end;

procedure TConfigForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  //Пишем InitialDir OpenDialog и SaveDialog
  WriteDialogsInitDir;

  CloseAction := caFree;
end;

//Чтение параметров напрямую из ~/.config/wdgui/rclone.conf
procedure TConfigForm.FormShow(Sender: TObject);
begin
  //В центр
  Left := MainForm.Left + MainForm.Width div 2 - ConfigForm.Width div 2;
  Top := MainForm.Top + MainForm.Height div 2 - ConfigForm.Height div 2;

  //Кнопки
  LoadBtn.Width := LoadBtn.Height;
  SaveBtn.Width := SaveBtn.Height;

  //Читаем InitialDir OpenDialog и SaveDialog
  ReadDialogsInitDir;

  //Читаем имя активного профиля
  ReadActiveProfile;
end;

{ https://webdav.yandex.ru
https://webdav.cloud.mail.ru
https://app.koofr.net/dav/Koofr }

//Выбор-Чтение профиля и предустановка URL сервера
procedure TConfigForm.ProfileBoxChange(Sender: TObject);
begin
  ReadProfile(ProfileBox.Text);

  ServerBox.Enabled := False;

  case ProfileBox.Text of
    'MAIL': ServerBox.ItemIndex := 1;
    'KOOFR': ServerBox.ItemIndex := 2;
    'YANDEX': ServerBox.ItemIndex := 0;
    'OTHER':
    begin
      ServerBox.Text := OtherServerURL;
      ServerBox.Enabled := True;
    end;
    else
      ServerBox.Text := '';
  end;
end;

end.
