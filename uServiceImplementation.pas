unit uServiceImplementation;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  IniFiles, WinSvc;

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
    procedure DumpTextFromHandle(Pipe: THandle);
    procedure LogDump(ABytes: RawByteString);
    procedure LogT(AMessage: string);
  end;

var
  HostService: THostService;

implementation

{$R *.DFM}

function StartService(Server: String; ServiceName: String): Boolean;
var
  SCH   : SC_HANDLE;
  SvcSCH: SC_HANDLE;
  Arg   : PChar;
begin
  SCH := OpenSCManager(PChar(Server), nil, SC_MANAGER_ALL_ACCESS);
  SvcSCH := OpenService(SCH, PChar(ServiceName), SERVICE_ALL_ACCESS);
  Arg := nil;
  Result := WinSvc.StartService(SvcSCH, 0, Arg);
end;

function StopService(Server: String; ServiceName: String): Boolean;
var
  SCH   : SC_HANDLE;
  SvcSCH: SC_HANDLE;
  Ss    : TServiceStatus;
begin
  SCH := OpenSCManager(PChar(Server), nil, SC_MANAGER_ALL_ACCESS);
  SvcSCH := OpenService(SCH, PChar(ServiceName), SERVICE_ALL_ACCESS);
  Result := WinSvc.ControlService(SvcSCH, SERVICE_CONTROL_STOP, ss);
end;


procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  HostService.Controller(CtrlCode);
end;

procedure THostService.DumpTextFromHandle(Pipe: THandle);
const
  BufferSize = 2048;
var
  BytesRead: Cardinal;
  Buffer: RawByteString;
begin
  BytesRead := 0;
  PeekNamedPipe(Pipe, nil, 0, nil, @BytesRead, nil);
  if BytesRead = 0 then
    Exit;

  SetLength(Buffer, BufferSize);
  repeat
    ReadFile(Pipe, Buffer[1], BufferSize, BytesRead, nil);
    if BytesRead > 0 then
      LogDump(Copy(Buffer, 1, BytesRead));
  until BytesRead < BufferSize;
  SetLength(Buffer, 0);
end;

function THostService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure THostService.LogDump(ABytes: RawByteString);
var
  FS: TFileStream;
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
    FS.Write(ABytes[1], Length(ABytes));
  finally
    FS.Free;
  end;
end;

procedure THostService.LogT(AMessage: string);
begin
  LogDump(UTF8Encode('*** ' + FormatDateTime('yyyy-MM-dd hh:mm:ss ', Now) + AMessage + #13#10));
end;

procedure THostService.ServiceAfterInstall(Sender: TService);
begin
  LogT('Service successfuly installed!');
end;

procedure THostService.ServiceCreate(Sender: TObject);
begin
  SetCurrentDir(ExtractFilePath(ParamStr(0)));
  Config := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  Name := Config.ReadString('Service', 'Name', 'AppHostService');
  DisplayName := Config.ReadString('Service', 'DisplayName', 'AppHostService');
  LogT('---');
  LogT(Format('Created service instance: %s (%s)', [Name, DisplayName]));

  if FindCmdLineSwitch('start', ['-', '/'], True) then
    StartService('', Name);
  if FindCmdLineSwitch('stop', ['-', '/'], True) then
    StopService('', Name);
end;

procedure THostService.ServiceExecute(Sender: TService);
var
  Security: TSecurityAttributes;
  ReadPipe, WritePipe: THandle;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  AppIsRunning: Boolean;
  AppCommandLine: string;
begin
  Security.nLength := SizeOf(TSecurityAttributes);
  Security.bInheritHandle := True;
  Security.lpSecurityDescriptor := nil;

  if not CreatePipe(ReadPipe, WritePipe, @Security, 0) then
  begin
    LogT('Failed to create read/write pipe: ' + SysErrorMessage(GetLastError));
    Exit;
  end;

  FillChar(StartupInfo, SizeOf(TStartupInfo), 0);
  StartupInfo.cb := SizeOf(TStartupInfo);
  StartupInfo.hStdError := WritePipe;
  StartupInfo.hStdOutput := WritePipe;
  StartupInfo.dwFlags := STARTF_USESTDHANDLES + STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;

  AppCommandLine := Config.ReadString('Service', 'Cmd', '');
  LogT('Running ' + AppCommandLine);

  if not CreateProcess(nil, PChar(AppCommandLine), @Security, @Security, True,
    NORMAL_PRIORITY_CLASS, nil, nil, StartupInfo, ProcessInfo)
  then
  begin
    LogT('Failed to create process: ' + SysErrorMessage(GetLastError));
    Exit;
  end;

  LogT('Created process with handle = ' + IntToStr(ProcessInfo.dwProcessId));

  while True do
  begin
    AppIsRunning := WaitForSingleObject(ProcessInfo.hProcess, 100) = WAIT_TIMEOUT;
    DumpTextFromHandle(ReadPipe);
    if not AppIsRunning then
    begin
      LogT('App terminated');
      Break;
    end;

    ServiceThread.ProcessRequests(False);
    if Terminated then
    begin
      LogT('Service is terminated, killing the process');
      TerminateProcess(ProcessInfo.hProcess, 1);
      Break;
    end;
  end;

  CloseHandle(ProcessInfo.hProcess);
  CloseHandle(ProcessInfo.hThread);
  CloseHandle(ReadPipe);
  CloseHandle(WritePipe);
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
