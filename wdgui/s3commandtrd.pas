unit S3CommandTRD;

{$mode objfpc}{$H+}

interface

uses
  Forms, Classes, Process, SysUtils, ComCtrls;

type

  { StartS3Command }

  StartS3Command = class(TThread)
  private
    Jobs: TStringList;
    Log: TStringList;

    procedure ShowLog;
    procedure StartProgress;
    procedure StopProgress;

  protected
    procedure Execute; override;
  public
    constructor Create(const AJobs: TStringList);
  end;

implementation

uses
  Unit1;


{ ---------------------------------------------------------------------------
  Создание потока
  --------------------------------------------------------------------------- }

constructor StartS3Command.Create(const AJobs: TStringList);
begin
  inherited Create(True);

  FreeOnTerminate := True;

  // Собственная копия списка заданий.
  // GUI после запуска потока может менять исходный список.
  Jobs := TStringList.Create;
  Jobs.Assign(AJobs);

  // Общий лог потока
  Log := TStringList.Create;

  Start;
end;


{ ---------------------------------------------------------------------------
  Выполнение заданий
  --------------------------------------------------------------------------- }

procedure StartS3Command.Execute;
var
  ExProcess: TProcess;
  i: integer;
begin
  try
    Synchronize(@StartProgress);

    i := 0;

    while i + 2 < Jobs.Count do
    begin

      ExProcess := TProcess.Create(nil);

      try
        // Запускаем rclone
        ExProcess.Executable := 'rclone';

        ExProcess.Parameters.Add('--config');
        ExProcess.Parameters.Add(GetUserDir + '.config/wdgui/rclone.conf');

        // Progress
        ExProcess.Parameters.Add('-P');

        ExProcess.Parameters.Add(Jobs[i]);

        // Источник
        ExProcess.Parameters.Add(Jobs[i + 1]);

        // Назначение
        ExProcess.Parameters.Add(Jobs[i + 2]);

        // stdout + stderr идут в один pipe
        ExProcess.Options := [poUsePipes, poStderrToOutPut];

        ExProcess.Execute;

        // Читаем вывод rclone во время работы
        while ExProcess.Running do
        begin
          if ExProcess.Output.NumBytesAvailable > 0 then
          begin
            Log.Clear;
            Log.LoadFromStream(ExProcess.Output);

            if Log.Count > 0 then
              Synchronize(@ShowLog);
          end;

          Sleep(100);
        end;

        // Дочитываем остаток вывода после завершения процесса
        if ExProcess.Output.NumBytesAvailable > 0 then
        begin
          Log.LoadFromStream(ExProcess.Output);

          if Log.Count > 0 then
            Synchronize(@ShowLog);
        end;

      finally
        ExProcess.Free;
      end;
      Inc(i, 3);
    end;

  finally
    Synchronize(@StopProgress);

    Log.Free;
    Jobs.Free;
  end;
end;


{ ---------------------------------------------------------------------------
  Старт индикатора
  --------------------------------------------------------------------------- }

procedure StartS3Command.StartProgress;
begin
  with MainForm do
  begin
    LogMemo.Clear;

    // Запрещаем параллельные операции
    Panel4.Enabled := False;
    Panel3.Enabled := False;

    // Метка отмены
    Panel4.Caption := SCancelCopyng;

    Application.ProcessMessages;

    // Бегущий индикатор
    ProgressBar1.Style := pbstMarquee;
    ProgressBar1.Repaint;
  end;
end;


{ ---------------------------------------------------------------------------
  Останов индикатора
  --------------------------------------------------------------------------- }

procedure StartS3Command.StopProgress;
begin
  with MainForm do
  begin
    Application.ProcessMessages;

    // Останавливаем индикатор
    ProgressBar1.Style := pbstNormal;
    ProgressBar1.Repaint;

    // Убираем надпись Esc
    Panel4.Caption := '';

    // Обновляем соответствующую панель
    if left_panel then
      CompDirUpdate
    else
      StartLS;
  end;
end;


{ ---------------------------------------------------------------------------
  Вывод лога
  --------------------------------------------------------------------------- }

procedure StartS3Command.ShowLog;
var
  i: integer;
begin
  // Выводим строки из буфера
  for i := 0 to Log.Count - 1 do
    MainForm.LogMemo.Lines.Append(Log[i]);

  // Курсор в конец
  MainForm.LogMemo.SelStart :=
    Length(MainForm.LogMemo.Text);

  // Не позволяем логу расти бесконечно
  if MainForm.LogMemo.Lines.Count > 500 then
    MainForm.LogMemo.Clear;
end;


end.
