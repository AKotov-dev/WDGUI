program wdgui;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,   {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Unit1,
  config_unit,
  about_unit, rclone_check_trd;

  {$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='WDGUI v0.3';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
