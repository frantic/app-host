unit uServiceImplementation;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  IniFiles;

type
  THostService = class(TService)
    procedure ServiceCreate(Sender: TObject);
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceExecute(Sender: TService);
  private
    Config: TIniFile;
  public
    function GetServiceController: TServiceController; override;
    procedure Log(AMessage: string);
    procedure LogT(AMessage: string);
  end;

var
  HostService: THostService;

implementation

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  HostService.Controller(CtrlCode);
end;

function THostService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure THostService.Log(AMessage: string);
var
  FS: TFileStream;
  MsgWithCRLF: RawByteString;
  FileName: string;
  OpenMode: Word;
begin
  FileName := ChangeFileExt(ParamStr(0), '.log');
  if FileExists(FileName) then
    OpenMode := fmOpenReadWrite
  else
    OpenMode := fmCreate;

  FS := TFileStream.Create(FileName, OpenMode or fmShareDenyNone);
  try
    FS.Seek(0, soFromEnd);
    MsgWithCRLF := UTF8Encode(AMessage + #13#10);
    FS.Write(MsgWithCRLF[1], Length(MsgWithCRLF));
  finally
    FS.Free;
  end;
end;

procedure THostService.LogT(AMessage: string);
begin
  Log(FormatDateTime('yyyy-MM-dd hh:mm:ss ', Now) + AMessage);
end;

procedure THostService.ServiceAfterInstall(Sender: TService);
begin
  LogT('Service successfuly installed!');
end;

procedure THostService.ServiceCreate(Sender: TObject);
begin
  Config := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  Name := Config.ReadString('Service', 'Name', 'AppHostService');
  DisplayName := Config.ReadString('Service', 'DisplayName', 'AppHostService');
  LogT(Format('Created service instance: %s (%s)', [Name, DisplayName]));
end;

procedure THostService.ServiceExecute(Sender: TService);
begin
  Sleep(2000);
end;

procedure THostService.ServiceShutdown(Sender: TService);
begin
  LogT('Shutdown');
end;

procedure THostService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  LogT('Service started');
end;

procedure THostService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  LogT('Service stopped');
end;

end.
