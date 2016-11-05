#define MyAppName "Application"
#define MyAppVersion "1.1.1"
#define MyAppPublisher "Application Productions"
#define MyAppURL "https://sourceforge.net/projects/"
#define MyAppExeName "application.exe"

#define MyAppSvcName "application"
#define MyAppDesc "My Windows Service"
#define MyProgramFiles "C:\Program Files (x86)"

[Setup]
AppName=test
AppVerName=test

CreateAppDir=false
UsePreviousAppDir=false
UsePreviousGroup=false
AlwaysShowComponentsList=false
ShowComponentSizes=false
FlatComponentsList=false
UsePreviousSetupType=false
UsePreviousTasks=false
UsePreviousUserInfo=false
DisableStartupPrompt=true

[_ISTool]
EnableISX=true

[Code]
type
	SERVICE_STATUS = record
    	dwServiceType				: cardinal;
    	dwCurrentState				: cardinal;
    	dwControlsAccepted			: cardinal;
    	dwWin32ExitCode				: cardinal;
    	dwServiceSpecificExitCode	: cardinal;
    	dwCheckPoint				: cardinal;
    	dwWaitHint					: cardinal;
	end;
	HANDLE = cardinal;

const
	SERVICE_QUERY_CONFIG		= $1;
	SERVICE_CHANGE_CONFIG		= $2;
	SERVICE_QUERY_STATUS		= $4;
	SERVICE_START				= $10;
	SERVICE_STOP				= $20;
	SERVICE_ALL_ACCESS			= $f01ff;
	SC_MANAGER_ALL_ACCESS		= $f003f;
	SERVICE_WIN32_OWN_PROCESS	= $10;
	SERVICE_WIN32_SHARE_PROCESS	= $20;
	SERVICE_WIN32				= $30;
	SERVICE_INTERACTIVE_PROCESS = $100;
	SERVICE_BOOT_START          = $0;
	SERVICE_SYSTEM_START        = $1;
	SERVICE_AUTO_START          = $2;
	SERVICE_DEMAND_START        = $3;
	SERVICE_DISABLED            = $4;
	SERVICE_DELETE              = $10000;
	SERVICE_CONTROL_STOP		= $1;
	SERVICE_CONTROL_PAUSE		= $2;
	SERVICE_CONTROL_CONTINUE	= $3;
	SERVICE_CONTROL_INTERROGATE = $4;
	SERVICE_STOPPED				= $1;
	SERVICE_START_PENDING       = $2;
	SERVICE_STOP_PENDING        = $3;
	SERVICE_RUNNING             = $4;
	SERVICE_CONTINUE_PENDING    = $5;
	SERVICE_PAUSE_PENDING       = $6;
	SERVICE_PAUSED              = $7;

// #######################################################################################
// nt based service utilities
// #######################################################################################
function OpenSCManager(lpMachineName, lpDatabaseName: string; dwDesiredAccess :cardinal): HANDLE;
external 'OpenSCManagerA@advapi32.dll stdcall';

function OpenService(hSCManager :HANDLE;lpServiceName: string; dwDesiredAccess :cardinal): HANDLE;
external 'OpenServiceA@advapi32.dll stdcall';

function CloseServiceHandle(hSCObject :HANDLE): boolean;
external 'CloseServiceHandle@advapi32.dll stdcall';

function CreateService(hSCManager :HANDLE;lpServiceName, lpDisplayName: string;dwDesiredAccess,dwServiceType,dwStartType,dwErrorControl: cardinal;lpBinaryPathName,lpLoadOrderGroup: String; lpdwTagId : cardinal;lpDependencies,lpServiceStartName,lpPassword :string): cardinal;
external 'CreateServiceA@advapi32.dll stdcall';

function DeleteService(hService :HANDLE): boolean;
external 'DeleteService@advapi32.dll stdcall';

function StartNTService(hService :HANDLE;dwNumServiceArgs : cardinal;lpServiceArgVectors : cardinal) : boolean;
external 'StartServiceA@advapi32.dll stdcall';

function ControlService(hService :HANDLE; dwControl :cardinal;var ServiceStatus :SERVICE_STATUS) : boolean;
external 'ControlService@advapi32.dll stdcall';

function QueryServiceStatus(hService :HANDLE;var ServiceStatus :SERVICE_STATUS) : boolean;
external 'QueryServiceStatus@advapi32.dll stdcall';

function QueryServiceStatusEx(hService :HANDLE;ServiceStatus :SERVICE_STATUS) : boolean;
external 'QueryServiceStatus@advapi32.dll stdcall';

function OpenServiceManager() : HANDLE;
begin
	if UsingWinNT() = true then begin
		Result := OpenSCManager('','ServicesActive',SC_MANAGER_ALL_ACCESS);
		if Result = 0 then
			MsgBox('the servicemanager is not available', mbError, MB_OK)
	end
	else begin
			MsgBox('only nt based systems support services', mbError, MB_OK)
			Result := 0;
	end
end;

function IsServiceInstalled(ServiceName: string) : boolean;
var
	hSCM	: HANDLE;
	hService: HANDLE;
begin
	hSCM := OpenServiceManager();
	Result := false;
	if hSCM <> 0 then begin
		hService := OpenService(hSCM,ServiceName,SERVICE_QUERY_CONFIG);
        if hService <> 0 then begin
            Result := true;
            CloseServiceHandle(hService)
		end;
        CloseServiceHandle(hSCM)
	end
end;

function InstallService(FileName, ServiceName, DisplayName, Description : string;ServiceType,StartType :cardinal) : boolean;
var
	hSCM	: HANDLE;
	hService: HANDLE;
begin
	hSCM := OpenServiceManager();
	Result := false;
	if hSCM <> 0 then begin
		hService := CreateService(hSCM,ServiceName,DisplayName,SERVICE_ALL_ACCESS,ServiceType,StartType,0,FileName,'',0,'','','');
		if hService <> 0 then begin
			Result := true;
			// Win2K & WinXP supports aditional description text for services
			if Description<> '' then
				RegWriteStringValue(HKLM,'System\CurrentControlSet\Services' + ServiceName,'Description',Description);
			CloseServiceHandle(hService)
		end;
        CloseServiceHandle(hSCM)
	end
end;

function RemoveService(ServiceName: string) : boolean;
var
	hSCM	: HANDLE;
	hService: HANDLE;
begin
	hSCM := OpenServiceManager();
	Result := false;
	if hSCM <> 0 then begin
		hService := OpenService(hSCM,ServiceName,SERVICE_DELETE);
        if hService <> 0 then begin
            Result := DeleteService(hService);
            CloseServiceHandle(hService)
		end;
        CloseServiceHandle(hSCM)
	end
end;

function StartService(ServiceName: string) : boolean;
var
	hSCM	: HANDLE;
	hService: HANDLE;
begin
	hSCM := OpenServiceManager();
	Result := false;
	if hSCM <> 0 then begin
		hService := OpenService(hSCM,ServiceName,SERVICE_START);
        if hService <> 0 then begin
        	Result := StartNTService(hService,0,0);
            CloseServiceHandle(hService)
		end;
        CloseServiceHandle(hSCM)
	end;
end;

function StopService(ServiceName: string) : boolean;
var
	hSCM	: HANDLE;
	hService: HANDLE;
	Status	: SERVICE_STATUS;
begin
	hSCM := OpenServiceManager();
	Result := false;
	if hSCM <> 0 then begin
		hService := OpenService(hSCM,ServiceName,SERVICE_STOP);
        if hService <> 0 then begin
        	Result := ControlService(hService,SERVICE_CONTROL_STOP,Status);
            CloseServiceHandle(hService)
		end;
        CloseServiceHandle(hSCM)
	end;
end;

function IsServiceRunning(ServiceName: string) : boolean;
var
	hSCM	: HANDLE;
	hService: HANDLE;
	Status	: SERVICE_STATUS;
begin
	hSCM := OpenServiceManager();
	Result := false;
	if hSCM <> 0 then begin
		hService := OpenService(hSCM,ServiceName,SERVICE_QUERY_STATUS);
    	if hService <> 0 then begin
			if QueryServiceStatus(hService,Status) then begin
				Result :=(Status.dwCurrentState = SERVICE_RUNNING)
        	end;
            CloseServiceHandle(hService)
		    end;
        CloseServiceHandle(hSCM)
	end
end;

// #######################################################################################
// version functions
// #######################################################################################
function CheckVersion(Filename : string;hh,hl,lh,ll : integer) : boolean;
var
	VersionMS	: cardinal;
	VersionLS	: cardinal;
	CheckMS		: cardinal;
	CheckLS		: cardinal;
begin
	if GetVersionNumbers(Filename,VersionMS,VersionLS) = false then
		Result := false
	else begin
		CheckMS := (hh shl $10) or hl;
		CheckLS := (lh shl $10) or ll;
		Result := (VersionMS > CheckMS) or ((VersionMS = CheckMS) and (VersionLS >= CheckLS));
	end;
end;

// Some examples for version checking
function NeedShellFolderUpdate() : boolean;
begin
	Result := CheckVersion('ShFolder.dll',5,50,4027,300) = false;
end;

function NeedVCRedistUpdate() : boolean;
begin
	Result := (CheckVersion('mfc42.dll',6,0,8665,0) = false)
		or (CheckVersion('msvcrt.dll',6,0,8797,0) = false)
		or (CheckVersion('comctl32.dll',5,80,2614,3600) = false);
end;

function NeedHTMLHelpUpdate() : boolean;
begin
	Result := CheckVersion('hh.exe',4,72,0,0) = false;
end;

function NeedWinsockUpdate() : boolean;
begin
	Result := (UsingWinNT() = false) and (CheckVersion('mswsock.dll',4,10,0,1656) = false);
end;

function NeedDCOMUpdate() : boolean;
begin
	Result := (UsingWinNT() = false) and (CheckVersion('oleaut32.dll',2,30,0,0) = false);
end;

// function IsServiceInstalled(ServiceName: string) : boolean;
// function IsServiceRunning(ServiceName: string) : boolean;
// function InstallService(FileName, ServiceName, DisplayName, Description : string;ServiceType,StartType :cardinal) : boolean;
// function RemoveService(ServiceName: string) : boolean;
// function StartService(ServiceName: string) : boolean;
// function StopService(ServiceName: string) : boolean;

// function SetupService(service, port, comment: string) : boolean;

// function CheckVersion(Filename : string;hh,hl,lh,ll : integer) : boolean;


function InitializeSetup(): boolean;
begin
	if IsServiceInstalled('{#MyAppSvcName}') = true then begin
    Log('InitializeSetup: {#MyAppSvcName} is running');
  end
  else begin
    Log('InitializeSetup: {#MyAppSvcName} is not running');
  end;

	Result := true
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  Log('CurStepChanged(' + IntToStr(Ord(CurStep)) + ') called');
  if CurStep = ssInstall then begin
    if IsServiceInstalled('{#MyAppSvcName}') = true then begin
      StopService('{#MyAppSvcName}');
      repeat
        Sleep(500);
      until IsServiceRunning('{#MyAppSvcName}') = false;
      RemoveService('{#MyAppSvcName}');
    end;
  end
  else if CurStep = ssPostInstall then
    if IsServiceInstalled('{#MyAppSvcName}') = false then begin
      if InstallService('{#MyProgramFiles}\{#MyAppName}\{#MyAppExeName}','{#MyAppSvcName}','{#MyAppName}','{#MyAppDesc}',SERVICE_WIN32_OWN_PROCESS,SERVICE_AUTO_START) = true then begin
			  StartService('{#MyAppSvcName}');
      end;
    end
    else
      Log('CurStepChanged (ssPostInstall): {#MyAppSvcName} is already installed!');

end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  Log('CurUninstallStepChanged(' + IntToStr(Ord(CurUninstallStep)) + ') called');
  if CurUninstallStep = usUninstall then begin
    if IsServiceInstalled('{#MyAppSvcName}') = true then begin
      StopService('{#MyAppSvcName}');
      repeat
        Sleep(500);
      until IsServiceRunning('{#MyAppSvcName}') = false;
      RemoveService('{#MyAppSvcName}');
    end;
  end;
end;
