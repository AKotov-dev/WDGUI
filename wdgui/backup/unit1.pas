unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ShellCtrls, Buttons, ComCtrls, IniPropStorage, Types, Process,
  LCLType, DefaultTranslator, strutils, FileUtil;

type

  { TMainForm }

  TMainForm = class(TForm)
    Image1: TImage;
    RenameBtn: TSpeedButton;
    CompDir: TShellTreeView;
    SettingsBtn: TSpeedButton;
    CopyFromPC: TSpeedButton;
    CopyFromBucket: TSpeedButton;
    DelBtn: TSpeedButton;
    AddBtn: TSpeedButton;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    ImageList1: TImageList;
    IniPropStorage1: TIniPropStorage;
    MkPCDirBtn: TSpeedButton;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    ProgressBar1: TProgressBar;
    UpdateBtn: TSpeedButton;
    SDBox: TListBox;
    LogMemo: TMemo;
    SelectAllBtn: TSpeedButton;
    InfoBtn: TSpeedButton;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    UpBtn: TSpeedButton;
    procedure RenameBtnClick(Sender: TObject);
    procedure AddBtnClick(Sender: TObject);
    procedure CompDirGetImageIndex(Sender: TObject; Node: TTreeNode);
    procedure CopyFromBucketClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure InfoBtnClick(Sender: TObject);
    procedure SettingsBtnClick(Sender: TObject);
    procedure CopyFromPCClick(Sender: TObject);
    procedure DelBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MkPCDirBtnClick(Sender: TObject);
    procedure UpdateBtnClick(Sender: TObject);
    procedure CompDirUpdate;
    procedure SDBoxDblClick(Sender: TObject);
    procedure SDBoxDrawItem(Control: TWinControl; Index: integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure SelectAllBtnClick(Sender: TObject);
    procedure StartProcess(command: string);
    procedure StartLS;
    //    procedure StartCmd;
    procedure UpBtnClick(Sender: TObject);

  private

  public

  end;

var
  left_panel: boolean;

resourcestring
  SDelete = 'Delete selected objects?';
  SOverwriteObject = 'Overwrite existing objects?';
  SObjectExists = 'The folder already exists!';
  SCreateDir = 'Create directory';
  SInputName = 'Enter the name:';
  SCancelCopyng = 'Esc - cancel... ';
  SCloseQuery = 'Cadaver is active! Finish the process?';
  SNewBucket = 'Create a new directory';
  SBucketName = 'Directory name:';
  SRename = 'Rename an object';
  SNoData = 'Server, Login, and Password are required!';

var
  MainForm: TMainForm;

implementation

uses config_unit, about_unit, lsfoldertrd, S3CommandTRD;

  {$R *.lfm}

  { TMainForm }


//ls в директории . (SDBox)
procedure TMainForm.StartLS;
var
  FLSFolderThread: TThread;
begin
  FLSFolderThread := StartLSFolder.Create(False);
  FLSFolderThread.Priority := tpHighest; //tpHigher
end;


//Уровень вверх
procedure TMainForm.UpBtnClick(Sender: TObject);
var
  S: string;
begin
  S := GroupBox2.Caption;

  if (S <> '/') and (S <> '') then
  begin
    // Убираем завершающий слэш, чтобы ExtractFilePath понял, что это папка, а не файл
    if S[Length(S)] = '/' then
      SetLength(S, Length(S) - 1);

    // Функция вернет путь уровнем выше, уже с косым слэшем на конце (например, '/home/')
    S := ExtractFilePath(S);

    if S = '' then S := '/';

    GroupBox2.Caption := S;
  end;

  StartLS;
end;

//StartCommand (служебные команды)
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  try
    ExProcess := TProcess.Create(nil);
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    ExProcess.Options := [poWaitOnExit, poUsePipes];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Апдейт текущей директории CompDir (ShellTreeView)
procedure TMainForm.CompDirUpdate;
var
  i: integer; //Абсолютный индекс выделенного
  d: string; //Выделенная директория
begin
  try
    //Запоминаем позицию курсора
    i := CompDir.Selected.AbsoluteIndex;
    d := ExtractFilePath(CompDir.GetPathFromNode(CompDir.Selected));

    //Обновляем  выбранного родителя
    with CompDir do
      Refresh(Selected.Parent);

    //Курсор на созданную папку
    CompDir.Path := d;
    CompDir.Select(CompDir.Items[i]);
    CompDir.SetFocus;

    //Разрешаем операции
    Panel4.Enabled := True;
    Panel3.Enabled := True;

    //Останов индикатора
    Application.ProcessMessages;
    ProgressBar1.Style := pbstNormal;
    ProgressBar1.Repaint;
  except;
    //Если сбой - перечитать корень
    UpdateBtn.Click;
  end;
end;

//Сменить директорию облака (./../..)
procedure TMainForm.SDBoxDblClick(Sender: TObject);
begin
  if SDBox.SelCount <> 0 then
  begin
    if Pos('/', SDBox.Items.Strings[SDBox.ItemIndex]) <> 0 then
    begin
      GroupBox2.Caption := Trim(GroupBox2.Caption + SDBox.Items[SDBox.ItemIndex]);
      StartLS;
    end;
  end;
end;

//Прорисовка иконок панели '.'
procedure TMainForm.SDBoxDrawItem(Control: TWinControl; Index: integer;
  ARect: TRect; State: TOwnerDrawState);
var
  BitMap: TBitMap;
begin
  BitMap := TBitMap.Create;
  try
    ImageList1.GetBitMap(0, BitMap);

    with SDBox do
    begin
      Canvas.FillRect(aRect);

      //Вывод текста со сдвигом (общий)
      Canvas.TextOut(aRect.Left + 27, aRect.Top + ItemHeight div 2 -
        Canvas.TextHeight('A') div 2 + 1, Items[Index]);

      //Сверху иконки взависимости от последнего символа ('/')
      if Copy(Items[Index], Length(Items[Index]), 1) = '/' then
        //Иконка папки
        ImageList1.GetBitMap(0, BitMap)
      else
        //Иконка файла
        ImageList1.GetBitMap(1, BitMap);

      Canvas.Draw(aRect.Left + 2, aRect.Top + (ItemHeight - 22) div 2 + 2, BitMap);
    end;
  finally
    BitMap.Free;
  end;
end;

//Выделить всё
procedure TMainForm.SelectAllBtnClick(Sender: TObject);
begin
  SDBox.SelectAll;
end;

//Подстановка иконок папка/файл в ShellTreeView
procedure TMainForm.CompDirGetImageIndex(Sender: TObject; Node: TTreeNode);
begin
  if FileGetAttr(CompDir.GetPathFromNode(node)) and faDirectory <> 0 then
    Node.ImageIndex := 0
  else
    Node.ImageIndex := 1;
  Node.SelectedIndex := Node.ImageIndex;
end;

//Копирование из облака на компьютер
procedure TMainForm.CopyFromBucketClick(Sender: TObject);
var
  i: integer;
  ItemName: string;
  RemotePath: string;
  LocalPath: string;
  Jobs: TStringList;
  IsDir: boolean;
  e: boolean;
begin
  // Результат операции относится к левой панели
  left_panel := True;

  // Если ничего не выбрано - выход
  if SDBox.SelCount = 0 then
    Exit;

  Jobs := TStringList.Create;
  try
    e := False;

    // Локальный путь текущего каталога
    LocalPath := IncludeTrailingPathDelimiter(ExtractFilePath(
      CompDir.GetPathFromNode(CompDir.Selected)));

    for i := 0 to SDBox.Count - 1 do
    begin
      if not SDBox.Selected[i] then
        Continue;

      // Имя объекта из правой панели
      ItemName := SDBox.Items[i];

      // Каталог определяется только по последнему символу.
      // Например:
      //   888/       -> каталог
      //   test.txt   -> файл
      IsDir := (ItemName <> '') and (ItemName[Length(ItemName)] = '/');

      // Для формирования пути rclone убираем
      // завершающий '/' у каталога.
      if IsDir then
        ItemName := ExcludeTrailingPathDelimiter(ItemName);

      // Проверяем наличие объекта на компьютере
      if not e then
      begin
        if IsDir then
        begin
          if DirectoryExists(LocalPath + ItemName) then
            e := True;
        end
        else
        begin
          if FileExists(LocalPath + ItemName) then
            e := True;
        end;
      end;

      // Полный путь объекта на сервере
      RemotePath :=
        'server:' + IncludeTrailingPathDelimiter(GroupBox2.Caption) + ItemName;

      // ------------------------------------------------------------
      // ФАЙЛ

      // rclone -P copyto
      //   server:/file
      //   /local/file

      // ------------------------------------------------------------
      if not IsDir then
      begin
        Jobs.Add('copyto');
        Jobs.Add(RemotePath);
        Jobs.Add(LocalPath + ItemName);
      end

      // ------------------------------------------------------------
      // КАТАЛОГ

      // rclone -P copy
      //   server:/directory
      //   /local/directory

      // ------------------------------------------------------------
      else
      begin
        Jobs.Add('copy');
        Jobs.Add(RemotePath);
        Jobs.Add(LocalPath + ItemName);
      end;
    end;

    // Если хотя бы один объект уже существует
    if e then
    begin
      if MessageDlg(SOverwriteObject, mtConfirmation, [mbYes, mbNo], 0) <>
        mrYes then
        Exit;
    end;

    // Передаём задания в поток.
    // StartS3Command создаёт собственную копию Jobs,
    // поэтому после Create список можно освободить.
    StartS3Command.Create(Jobs);

  finally
    Jobs.Free;
  end;
end;

//Предупреждение о завершении обмена с облаком, если в прогрессе
procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
var
  RClonePID: string;
begin
  // Находим PID активного rclone
  RunCommand('bash', ['-c', 'pgrep -x rclone'], RClonePID);
  RClonePID := Trim(RClonePID);

  if RClonePID <> '' then
    if MessageDlg(SCloseQuery, mtWarning, [mbYes, mbCancel], 0) <> mrYes then
      Canclose := False
    else
    begin
      StartProcess('pkill -x rclone');
      CanClose := True;
    end;
end;

//Esc - отмена операций
procedure TMainForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  RClonePID: string;
begin
  if key = VK_ESCAPE then
  begin
    // Находим PID активного rclone
    RunCommand('bash', ['-c', 'pgrep -x rclone'], RClonePID);
    RClonePID := Trim(RClonePID);

    if RClonePID <> '' then
    begin
      StartProcess('pkill -x rclone');
      LogMemo.Append('Esc - Cancellation of the operation...');
    end;
  end;
end;

//Форма About
procedure TMainForm.InfoBtnClick(Sender: TObject);
begin
  AboutForm := TAboutForm.Create(Application);
  AboutForm.ShowModal;
end;


//Создание нового каталога
procedure TMainForm.AddBtnClick(Sender: TObject);
var
  S: string;
  Jobs: TStringList;
begin
  try
    S := '';
    Jobs := TStringList.Create;

    repeat
      if not InputQuery(SNewBucket, SBucketName, S) then
        Exit;
    until S <> '';

    // Создаём каталог на сервере.

    // rclone mkdir wdgui:/текущий/каталог/новый_каталог

    Jobs.Add('mkdir');
    Jobs.Add('server:' + IncludeTrailingPathDelimiter(
      GroupBox2.Caption) + Trim(S));
    Jobs.Add('');

    left_panel := False;

    StartS3Command.Create(Jobs);
  finally
    Jobs.Free;
  end;
end;

//Переименование файлов/каталогов на сервере
procedure TMainForm.RenameBtnClick(Sender: TObject);
var
  S: string;
  OldName: string;
  OldPath: string;
  NewPath: string;
  Jobs: TStringList;
begin
  if SDBox.SelCount = 0 then
    Exit;

  // Старое имя без завершающего '/' у каталога
  OldName := StringReplace(SDBox.Items[SDBox.ItemIndex], '/', '',
    [rfReplaceAll, rfIgnoreCase]);

  S := OldName;

  repeat
    if not InputQuery(SRename, SInputName, S) then
      Exit;
  until S <> '';

  // Полный путь старого объекта
  OldPath := 'server:' + IncludeTrailingPathDelimiter(GroupBox2.Caption) + OldName;

  // Полный путь нового объекта
  NewPath := 'server:' + IncludeTrailingPathDelimiter(GroupBox2.Caption) + Trim(S);

  // Один job:

  // moveto
  // wdgui:/старое
  // wdgui:/новое

  // RcloneJobs.Clear;
  try

    Jobs := TStringList.Create;

    Jobs.Add('moveto');
    Jobs.Add(OldPath);
    Jobs.Add(NewPath);

    left_panel := False;

    StartS3Command.Create(Jobs);
  finally
  end;
end;


//Форма конфигурации ~/.netrc
procedure TMainForm.SettingsBtnClick(Sender: TObject);
begin
  ConfigForm := TConfigForm.Create(Application);
  ConfigForm.ShowModal;
end;

//Копирование с компа в облако
procedure TMainForm.CopyFromPCClick(Sender: TObject);
var
  i, sd: integer;
  e: boolean;
  RemotePath: string;
  Jobs: TStringList;
begin
  try
    Jobs := TStringList.Create;

    left_panel := False;

    if (CompDir.Items.SelectionCount = 0) or CompDir.Items.Item[0].Selected then
      Exit;

    e := False;

    RemotePath := 'server:' + GroupBox2.Caption;

    // Проверяем совпадения
    for i := 0 to CompDir.Items.Count - 1 do
    begin
      if CompDir.Items[i].Selected then
      begin
        if not e then
          for sd := 0 to SDBox.Count - 1 do
          begin
            if CompDir.Items[i].Text = ExcludeTrailingPathDelimiter(
              SDBox.Items[sd]) then
            begin
              e := True;
              Break;
            end;
          end;
      end;
    end;

    // Спросить про перезапись
    if e and (MessageDlg(SOverwriteObject, mtConfirmation, [mbYes, mbNo], 0) <>
      mrYes) then
      Exit;

    // Формируем задания
    for i := 0 to CompDir.Items.Count - 1 do
    begin
      if CompDir.Items[i].Selected then
      begin

        // Каталог
        if DirectoryExists(CompDir.Items[i].GetTextPath) then
        begin
          Jobs.Add('copy');
          Jobs.Add(
            ExcludeTrailingPathDelimiter(CompDir.Items[i].GetTextPath));
          Jobs.Add(
            RemotePath + CompDir.Items[i].Text); //  + '/'
        end

        // Файл
        else
        begin
          Jobs.Add('copyto');
          Jobs.Add(
            CompDir.Items[i].GetTextPath);
          Jobs.Add(
            RemotePath + CompDir.Items[i].Text); // '/' +
        end;

      end;
    end;

    StartS3Command.Create(Jobs);
  finally
    Jobs.Free;
  end;
end;

// Удаление объекта(ов) на сервере
procedure TMainForm.DelBtnClick(Sender: TObject);
var
  i: integer;
  Jobs: TStringList;
  RemotePath: string;
begin
  // Ничего не выбрано или пользователь отказался
  if (SDBox.SelCount = 0) or (MessageDlg(SDelete, mtConfirmation, [mbYes, mbNo], 0) <>
    mrYes) then
    Exit;

  left_panel := False;

  Jobs := TStringList.Create;
  try
    for i := 0 to SDBox.Count - 1 do
    begin
      if not SDBox.Selected[i] then
        Continue;

      // Полный путь объекта на сервере
      if Pos('/', SDBox.Items[i]) <> 0 then
        // Каталог
        RemotePath := GroupBox2.Caption + SDBox.Items[i]
      else
        // Файл
        RemotePath := GroupBox2.Caption + '/' + SDBox.Items[i];

      // rclone удаляет файл
      if Pos('/', SDBox.Items[i]) = 0 then
        Jobs.Add('deletefile')
      else
        // rclone удаляет каталог со всем содержимым
        Jobs.Add('purge');

      Jobs.Add('server:' + RemotePath);
      Jobs.Add('');
    end;

    StartS3Command.Create(Jobs);

  finally
    Jobs.Free;
  end;
end;

//Домашняя папка юзера - корень
procedure TMainForm.FormCreate(Sender: TObject);
var
  bmp: TBitmap;
begin
  // Устраняем баг иконки приложения
  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf32bit;
    bmp.Assign(Image1.Picture.Graphic);
    Application.Icon.Assign(bmp);
  finally
    bmp.Free;
  end;

  CompDir.Root := ExcludeTrailingPathDelimiter(GetUserDir);
  CompDir.Items.Item[0].Selected := True;

  //Директория конфигураций
  if not DirectoryExists(GetUserDir + '.config/wdgui') then
    ForceDirectories(GetUserDir + '.config/wdgui');

  IniPropStorage1.IniFileName := GetUserDir + '.config/wdgui/wdgui.conf';
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  Caption := Application.Title;
  IniPropStorage1.Restore;

  //Коррекция размеров при масштабировании в Plasma
  Panel3.Height := CopyFromPC.Height + 14;
  Panel4.Height := Panel3.Height;

  //Проверяем подключение выводим ошибки в LogMemo = StartLS (.)
  StartLS;
end;

//Создать каталог на компьютере
procedure TMainForm.MkPCDirBtnClick(Sender: TObject);
var
  S: string;
begin
  //Флаг выбора панели
  left_panel := False;

  S := '';
  repeat
    if not InputQuery(SCreateDir, SInputName, S) then
      Exit
  until S <> '';

  //Если есть совпадения (перезапись файлов)
  if DirectoryExists(IncludeTrailingPathDelimiter(
    ExtractFilePath(CompDir.GetPathFromNode(CompDir.Selected))) + S) then
  begin
    MessageDlg(SObjectExists, mtWarning, [mbOK], 0);
    Exit;
  end;
  //Создаём директорию
  MkDir(IncludeTrailingPathDelimiter(
    ExtractFilePath(CompDir.GetPathFromNode(CompDir.Selected))) + S);

  //Обновляем содержимое выделенного нода
  CompDirUpdate;
end;

//Перечитываем домашнюю папку на компьютере
procedure TMainForm.UpdateBtnClick(Sender: TObject);
begin
  with CompDir do
  begin
    Select(CompDir.TopItem, [ssCtrl]);
    Refresh(CompDir.Selected.Parent);
    Select(CompDir.TopItem, [ssCtrl]);
    SetFocus;
  end;
end;

end.
