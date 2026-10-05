unit rclone_check_trd;   //Вывод версии RClone...

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Process;

type
  TRCloneCheckThread = class(TThread)
  private
    FInstalled: boolean;
    FVersion: string;
  protected
    procedure Execute; override;
    procedure UpdateUI;
  end;

implementation

uses unit1;


procedure TRCloneCheckThread.Execute;
var
  FullOutput: string;
  Lines: TStringList;
begin
  FInstalled := False;
  FVersion := '';

  if RunCommand('rclone', ['--version'], FullOutput, [poWaitOnExit, poUsePipes]) then
  begin
    FInstalled := True;

    Lines := TStringList.Create;
    try
      Lines.Text := FullOutput;

      if Lines.Count > 0 then
        while Lines.Count > 3 do
          Lines.Delete(3);

      FVersion := Trim(Lines.Text);
    finally
      Lines.Free;
    end;
  end;

  Synchronize(@UpdateUI);
end;

procedure TRCloneCheckThread.UpdateUI;
begin
  //Проверка установки RClone и наличия первой конфигурации
  if FInstalled then
    MainForm.LogMemo.Append(FVersion)
  else
    MainForm.LogMemo.Append(SRCloneNotFound);
end;

end.
