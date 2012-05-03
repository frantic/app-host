object HostService: THostService
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = 'HostService'
  AfterInstall = ServiceAfterInstall
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
