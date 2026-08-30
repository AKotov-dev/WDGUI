unit config_unit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, Process, LCLType, IniFiles;

type

  { TConfigForm }

  TConfigForm = class(TForm)
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
  private

  public

  end;

var
  ConfigForm: TConfigForm;

implementation

uses unit1;

  {$R *.lfm}

  { TConfigForm }

procedure TConfigForm.OkBtnClick(Sender: TObject);
var
  S: TStringList;
  password: string;
begin
  //Обновить правую панель, если подключение состоялось
  left_panel := False;
  //Делаем новый ~/.netrc и сохраняем
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
    begin
      proxy := Trim(ProxyEdit.Text);
      S.Add('override.http_proxy = ' + Trim(ProxyEdit.Text));
    end
    else
      proxy := '';

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
var
  password: string;
begin
  //В центр
  ConfigForm.Left := MainForm.Left + MainForm.Width div 2 - ConfigForm.Width div 2;
  ConfigForm.Top := MainForm.Top + MainForm.Height div 2 - ConfigForm.Height div 2;

  if FileExists(GetUserDir + '.config/wdgui/rclone.conf') then
    with TIniFile.Create(GetUserDir + '.config/wdgui/rclone.conf') do
    try
      ServerBox.Text := Trim(ReadString('server', 'url', ''));
      LoginEdit.Text := Trim(ReadString('server', 'user', ''));

      //password
      if RunCommand('rclone', ['reveal', Trim(ReadString('server', 'pass', ''))],
        password) then
        PasswordEdit.Text := Trim(password);

      ProxyEdit.Text := Trim(ReadString('server', 'override.http_proxy', ''));
    finally
      Free;
    end;
end;

end.
