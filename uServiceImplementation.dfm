object HostService: THostService
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = 'HostService'
  AfterInstall = ServiceAfterInstall
  OnExecute = ServiceExecute
  OnShutdown = ServiceShutdown
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
