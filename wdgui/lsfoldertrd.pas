unit LSFolderTRD;

{$mode objfpc}{$H+}

interface

uses
  Classes, Process, SysUtils, Forms, Controls, ComCtrls;

type

  StartLSFolder = class(TThread)
  private
    S: TStringList;

    procedure UpdateSDBox;
    procedure ShowProgress;
    procedure StopProgress;
    procedure SortSDBox;

  protected
    procedure Execute; override;
  end;

implementation

uses
  Unit1;


{ ---------------------------------------------------------------------------
  Апдейт текущего каталога
  --------------------------------------------------------------------------- }

procedure StartLSFolder.Execute;
var
  ExProcess: TProcess;
begin
  try
    Synchronize(@ShowProgress);

    S := TStringList.Create;

    FreeOnTerminate := True;

    ExProcess := TProcess.Create(nil);
    try
      ExProcess.Executable := 'rclone';

      ExProcess.Parameters.Add('--config');
      ExProcess.Parameters.Add(GetUserDir + '.config/wdgui/rclone.conf');

      ExProcess.Options := [poWaitOnExit, poUsePipes];

      // ls текущего каталога
      ExProcess.Parameters.Add('lsf');
      ExProcess.Parameters.Add(
        'server:' + MainForm.GroupBox2.Caption
        );

      ExProcess.Execute;

      S.LoadFromStream(ExProcess.Output);

      Synchronize(@UpdateSDBox);

    finally
      ExProcess.Free;
    end;

  finally
    Synchronize(@StopProgress);

    S.Free;
  end;
end;


{ ---------------------------------------------------------------------------
  Начало операции
  --------------------------------------------------------------------------- }

procedure StartLSFolder.ShowProgress;
begin
  Application.ProcessMessages;

  MainForm.ProgressBar1.Style := pbstMarquee;
  MainForm.ProgressBar1.Repaint;
end;


{ ---------------------------------------------------------------------------
  Конец операции
  --------------------------------------------------------------------------- }

procedure StartLSFolder.StopProgress;
begin
  with MainForm do
  begin
    Panel4.Enabled := True;
    Panel3.Enabled := True;

    Application.ProcessMessages;

    ProgressBar1.Style := pbstNormal;
    ProgressBar1.Repaint;
  end;
end;


{ ---------------------------------------------------------------------------
  Сортировка:
  сначала каталоги, затем файлы.
  Внутри групп - по алфавиту.
  --------------------------------------------------------------------------- }

procedure StartLSFolder.SortSDBox;
var
  i, j: integer;
  A, B: string;
  AIsDir, BIsDir: boolean;
begin
  with MainForm.SDBox.Items do
  begin
    for i := 0 to Count - 2 do
      for j := i + 1 to Count - 1 do
      begin
        A := Strings[i];
        B := Strings[j];

        AIsDir := (A <> '') and (A[Length(A)] = '/');

        BIsDir := (B <> '') and (B[Length(B)] = '/');

        // Если A - файл, а B - каталог,
        // меняем их местами.
        if (not AIsDir) and BIsDir then
        begin
          Strings[i] := B;
          Strings[j] := A;
        end

        // Если оба одного типа -
        // сортируем по алфавиту.
        else if AIsDir = BIsDir then
        begin
          if CompareText(A, B) > 0 then
          begin
            Strings[i] := B;
            Strings[j] := A;
          end;
        end;
      end;
  end;
end;


{ ---------------------------------------------------------------------------
  Вывод ls в SDBox
  --------------------------------------------------------------------------- }

procedure StartLSFolder.UpdateSDBox;
begin
  with MainForm do
  begin
    // Получили новый список
    SDBox.Items.Assign(S);

    // Каталоги сверху, файлы снизу
    SortSDBox;

    // Обновляем содержимое
    SDBox.Refresh;

    // Фокусируем
    SDBox.SetFocus;

    // Если список не пуст - курсор в "0"
    if SDBox.Count <> 0 then
      SDBox.ItemIndex := 0;
  end;
end;

end.
