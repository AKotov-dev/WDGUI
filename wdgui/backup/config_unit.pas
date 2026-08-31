unit config_unit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, Process, LCLType, IniFiles;

type

  { TConfigForm }

  TConfigForm = class(TForm)
    ProfileBox: TComboBox;
    Label5: TLabel;
    ProxyEdit: TEdit;
    Label4: TLabel;
    ServerBox: TComboBox;
    Label3: TLabel;
    OkBtn: TBitBtn;
    CloseBtn: TBitBtn;
    LoginEdit: TEdit;
    PasswordEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure OkBtnClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ProfileBoxChange(Sender: TObject);
    procedure ReadProfile(Profile: string);


  private
  var
    OtherServerURL: string;

  public

  end;

var
  ConfigForm: TConfigForm;

implementation

uses unit1;

  {$R *.lfm}

  { TConfigForm }

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
  // if FileExists(GetUserDir + '.config/wdgui/wdgui.conf') then
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

procedure TConfigForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
end;

//Чтение параметров напрямую из ~/.config/wdgui/rclone.conf
procedure TConfigForm.FormShow(Sender: TObject);
begin
  //В центр
  ConfigForm.Left := MainForm.Left + MainForm.Width div 2 - ConfigForm.Width div 2;
  ConfigForm.Top := MainForm.Top + MainForm.Height div 2 - ConfigForm.Height div 2;

  //Читаем имя активного профиля
  if FileExists(GetUserDir + '.config/wdgui/wdgui.conf') then
    with TIniFile.Create(GetUserDir + '.config/wdgui/wdgui.conf') do
    try
      ProfileBox.Text := ReadString('Settings', 'Profile', 'MAIL');
      ReadProfile(ProfileBox.Text);

      if ProfileBox.Text = 'OTHER' then ServerBox.Enabled := True;
    finally
      Free;
    end;
end;

//Выбор-Чтение профиля и предустановка URL сервера
procedure TConfigForm.ProfileBoxChange(Sender: TObject);
begin
  ReadProfile(ProfileBox.Text);

  ServerBox.Enabled := False;

  case ProfileBox.Text of
    'MAIL': ServerBox.ItemIndex := 1;
    'KOOFR': ServerBox.ItemIndex := 2;
    'YANDEX': ServerBox.ItemIndex := 3;
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
