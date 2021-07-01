#Requires -Version 3
[CmdLetBinding()]
param(

	#Output directory. This is where we will configure data collector to store perflogs, logs and other things that this script will collect.
		$DirectoryPath
		
	,#SQL instances which counters will be included in collect.
	 #Default is all running instances. 
		[string[]]$SqlInstance = @()
		
	,#no check for sql server instance
		[switch]$NoSqlInstances
	
		
	,#Alternate data collect name. By default use name of this script + '_' $directory name.
		$DataCollectorName = $null
		
	,#No include Operating System counters. By default is included.
		[switch]$NoSOCounters
		
	,#Include some additional sql server counters like erros, etc.
		[switch]$IncludeAdditionalCounters
		
	,#Include service broker counters 
		[switch]$IncludeBrokerCounters
		
	,#Include counters related to sql server replication 
		[switch]$IncludeReplicationCounters
		
	,#Include counters related to database mirroring and alawayson
		[switch]$IncludeHadrCounters
		
	,#NOt used anymore. Becomre deprecated in 1.2.0
		[switch]$NoShowConfig
		
	,#By default, perf counters collection is enabled. Using this, you disables it.
	 #Most time, this is just for debugging purposes. (you want collect performance counters, because this scripts born to do this).
	  [switch]$DisablePerfCollect  = $false
		
	,#Default maximum size to directories that store some collect.
	 #If this maximum is reached, script take action determined by -OnMax parameter.
		$MaxCollectSize 	= 2GB
		
	,#Default maximum amount of time to keep.
	 #Script will attempt keep this time of data. It will use the Last Modified date of generated files...
		$MaxCollectTime	= $null 
		
	,#Maximum size a single file generated can be.
	 #This will be used to setup directly in data colletor set (parameter -max of logman tool)
		$PerCounterFileMaxSize = 5MB	
		
	,#This is maximum time that this script will allow data collector run.
	 #After this time, this script will stop current collector, if running, and start again.
	 #based on this value, the script will set data collector to run a maximum amount of time (twice this time).
	 #If this script end unexpectdelly, thanks to this max time set on data collector, it will not runing indefinedly, avoiding consuming all disk space...
	 #Thus, this renew time helps powershell keep control on logman execution.
		$RenewFrequency 	= 300
		
	,#This is the frequency that script will check while waiting the renew time...
	 #Every this frequecncy, script will do some important checks like validating max size, collect time, etc.
		$CheckFrequency	= '1m'
		
	,#Seconds that scriot will sleep main loop.
		$SleepTime = 5
		
	,#Action to take when a max limit is reached. This controls actions to take specified by parameters start with "-Max".
		
		#oldremove 	- Remove oldest files up to get value bellow the respective extrapoled setting.
		#error		- Throw errrors
		
		[ValidateSet('oldremove','error')] #TODO: oldmove,error,zip,copyold,logonly
		$OnMax = "oldremove"
		
	,#If specifified, enables process collect.
	 #This is result of Get-Process cmdlet with important data about process resource usage like cpu and memory.
	 #This parameters control the frequency of this collects. FOr example, 5s for collect every 5 seconds. The real time can vary a litlle.
		$ProcessLogFrequency
		
	,#Max size of a single process log  file
		$ProcessLogMaxSize = 5MB
	
	,#Maximum time to keep process info collects.
	 #By default, keeps all
		$MaxProcessTime 
	

	,#Use powershell jobs to spawn a new separate process to collect process
		[switch]$ProcessLogJob
		
	,#Use powershell jobs to spawn a new separate process to collect process
		$ProcessJobMaxRuntime = $null

	,#Maximum size of perfcounters collection. In addittion to this, -MaxCollectSize controls size of all directories.
		$MaxCountersCollectSize  = $null
		
	,#Maximum size of process collection. In addittion to this, -MaxCollectSize controls size of all directories.
		$MaxProcessCollectSize  = $null
		
	,#Extra process to monitor...
		$ExtraProcessNames  = @()
		
	,#Force exclude this process names from list
		$ExcludeProcessNames  = @()
		
	,#Frequency of check for processes and isntances changes...
		$CheckChangesFreq = '1m'
		
	,#If marked, will collect process threads when colleciting process data. 
	 #Just collect if ProcessLogFrequency was enabled!
		[switch]$CollectThreads
		
		
	,#If marked, will collect kernel trace session.
	 #Test this, ebcause this can add significant overhead on Windows sytem!
		[switch]$KernelLog 
		
	,#Renew time of kernel log. This is time that script will configure data collector overall duration of kernel log.
	 #WARNING: If you put a high value and powershell script hangs or delay above we expect, kernel log will run this time without any control.
	 #			So keep this value time sufficient to dont let kernel log fill your disk.
		$KernelRenewFrequency = 20
		
	,#Max size of each kernel log file.
		$KernelLoggerFileMaxSize = 200MB
		
	,#Buffer size of kernel log.
	 #WARNING: Adjust this value only if you know deep knowledge of ETW architecture.
		$KernelLogBufferSize = $null
		
	,#Maximum size of kernel collection. In addittion to this, -MaxCollectSize controls size of all directories.
	 #$null means 10% of MaxCollectSize.
		$MaxKernelCollectSize  = $null
		
	,#Flags to include.
	 #See  https://docs.microsoft.com/en-us/windows/win32/api/evntrace/ns-evntrace-event_trace_properties , EnableFlags section to more details.
	 #Flags name are same names in this page without "EVENT_TRACE_FLAG", in lower case. Some flags differt a little in this pattern, like hard_faults (not memory_hard_faults), but all is self explanatory.
		[ValidateSet("alpc","cswitch","disk_file_io","disk_io"
					,"disk_io_init","dispatcher","dpc","driver"
					,"file_io","file_io_init","image_load","interrupt"
					,"job","hard_faults","page_faults"
					,"tcpip","no_sysconfig","process"
					,"process_counters","profile","registry","split_io"
					,"syscall","thread","vamap","virtual_alloc"
		)]
		$KernelFlags = @("process","thread","dispatcher","hard_faults","image_load","profile")
		

	,#Include additional flags in addition of "KernelFlags" (useful to add more in additiona defaults"
		[ValidateSet("alpc","cswitch","disk_file_io","disk_io"
					,"disk_io_init","dispatcher","dpc","driver"
					,"file_io","file_io_init","image_load","interrupt"
					,"job","hard_faults","page_faults"
					,"tcpip","no_sysconfig","process"
					,"process_counters","profile","registry","split_io"
					,"syscall","thread","vamap","virtual_alloc"
		)]
		$KernelAdditionalFlags = @()
		
	,#Use xperf to do kernel log. Xperf must be installed. If not installed, throws error.
	 #WARNING: Xperf log uses stackwalk parameter and it can lead more load on server. Use this parameter with caution and plan and monitor enablement of it.
		[switch]$XPerfLog
		
	,#Choose xperf 
		[ValidateSet("Base","DiagEasy","Diag","Latency","SysProf")]
		[string[]]
		$XPerfFlags = @("Base")
		
	,#Enable xperf stackwalk events...
		[ValidateSet("profile","CSwitch","ReadyThread","ImageLoad","ImageUnload","SyscallEnter","SyscallExit")]
		[string[]]
		$XPerfStackWalk = @("profile")
		
	,#Emable xperf collector run assync
		[switch]$XPerfJob = $false
		
	,#Collect sql data... (beta)
		$SqlLogFrequency = $null
		
	,#Start Sql log as a separate job. We recommend use this parameter because if connection with sql fails or delay, this no cause impacts in main process
		[switch]$SqlLogJob
		
	,#Max runtime of sql job. By default it uses same value as RenewFrequency parameter.
		$SqlJobMaxRuntime = $null
		
	,#MAx single file size of sql collect.
		$SqlLogMaxSize = 20MB
		
	,#Output file type of sql collects.
		[ValidateSet("xml","csv")]
		$SqlLogType = "csv"
		
	,#Control the CPU priority of schedule
		[ValidateSet("Idle","BelowNormal","Normal","AboveNormal","High","RealTime")]
		[string]
		$PriorityClass = "BelowNormal"

	,#Cleanup frequency. Internal cleanup 
		$CleanupSeconds = 60
		
	,#Max script runtime. by defaults, runs por up to 10min and ends.
		$MaxScriptRuntime = '1d'
		
	,#Progress frequency. This will be calculate automatically... Just set this for testing purposes.
		$ManualProgressFrequency = $null
		
	,#Frequency of internals data collect.
		$InternalCollectFrequency = '5m'
		
	,#If specified, enables counter collect history. 
	 #The counter collect history is a subset of main perf counters.
	 #that will be collected at HistorySampleInterval and have a separate max size. 
	 # So it is suitable to less data and can less precise, 
	 #but can use less space, thus allowing more time on directory.
		$MaxHistorySize	= $null
	
	,#Sampleing interval of history counters, in seconds.
		$HistorySampleInterval = 15
		
	,#Sampleing interval of history counters, in seconds.
		$HistoryRenewFrequency = '1h'
		
	,#Include full per database history... This can require more space on history.
	 #by default, only _Total are included
		[switch]$HistoryDatabaseFull
	
)

# Para o script caso encontre qualquer exceção 
$ErrorActionPreference = "Stop";

#Here is critical importnat part: Logging
#If this fail, the script can fail and no log will be generated (this is bad if running non interactive mode)
#SO, we will create logging functions, setup script log file... If all of this fail, then we will write to appplication log.
#Also, we will alwayson throw the error, in case user using powershell.exe to get what happening!

try {
	$VERSION = "1.4.0";
	$ExistingVariables = gci Variable:\ | ? { $_.name -ne 'VERSION' } | %{ $_.name };
	
	#important variables used by log function!
	if($VerbosePreference -ne 'SilentlyContinue'){
		$IsVerboseEnabled 	= $true
		$VerboseSource 		= "VerbosePreference";
	} else {
		$IsVerboseEnabled = $false;
	}
	
	$IsConsole = [Environment]::UserInteractive;
	$ScriptStartTime = (Get-Date)
	

	
	#The most importnat function of this script!
	#Will log to a file defined on "$ScriptLogFile"
	function log {
		param(
			 $Msg
			,[switch]$Verbose
			,$Buffer
			
		)
		
		$ts    	= (Get-date).toString("yyyy-MM-dd HH:mm:ss.fff");
		$IsError = $Msg -is [System.Management.Automation.ErrorRecord] -or $Msg -is [System.Exception];
		$IsVerbMessage = $Verbose;
	
		if($LogSource){
			$Msg = "[$LogSource] $Msg";
		}

		if($IsError){
			$Error 	= $Msg;
			$LogMsg = "$ts ERROR:$Error"
		} else {
			$LogMsg = "$ts "+$Msg;
		}
		
		$LogParametersFile = "$DirectoryPath\log.parameters.txt";


		#Check if write to screen...
		if($IsVerbMessage -and $IsVerboseEnabled -and $IsConsole){
			write-verbose $LogMsg;
		}
		elseif(!$IsVerbMessage -and $IsConsole) {
			write-host $LogMsg
		}
		
		
		if($ScriptLogFile){
			if($IsVerbMessage){
				$LogMsg = "$ts [VERBOSE]$LogMsg"
			}
			
			$MustLog = !$IsVerbMessage -or ($IsVerbMessage -and $IsVerboseEnabled)
			
			if($MustLog){
				$LogMsg >> $ScriptLogFile;
			}
		}
		
		if($Buffer -ne $null){
			try {
				$BufferVar = get-variable  -Name $Buffer;
				$BufferVar.Value += $Msg;
			} catch {
				if($IsConsole){
					write-host "LOGTOBUFFER_ERROR: buffer:$buffer | Error: $_ | SourceLine: $($MyInvocation.ScriptLineNumber) | Source:$($MyInvocation.Line)";
					throw;
				}
			}
		}
		
		if($IsError){
			throw $Error;
		}	
	}

	log "Script started...";
	
	if(!$DirectoryPath){
		throw "Must specify -DirectoryPath parameter"
	}
	
	#Create if not exists...
	$DirectoryItem = mkdir -f $DirectoryPath;

	$ScriptLogFile = "$DirectoryPath\log.log";
	if(Test-Path $ScriptLogFile){
		remove-item $ScriptLogFile;
	}
	log "Start logging to file at $ScriptLogFile"
	log "Version: $VERSION. Pid:$PID"
} catch {
	$Original = $_;
	$LogMsg = "Script $PSCommandPath failed to initiate logging. Run in powershell.exe to get more details. Error was: $_. "
	try {
		Write-EventLog -LogName Application -Source Application -Message $LogMsg -EventId 1 -EntryType Error
	} finally {
		#if fails writelog, throws original exceptions back  (in case runing powershell.exe)
		throw $Original;
	}
}

try {
	#### Functions area
	$ExistingFunctions = gci Function:\ | ? { $_.name -ne 'log' } | %{ $_.name };
	
	#CORE FUNCTIONS
	
		#Get parameters of current script.
		function GetParameters(){
			$ParameterList = $ScriptInvocation.MyCommand.Parameters;
			$Params = @{};
			foreach($P in $ParameterList.GetEnumerator()){
				$ParamName = $P.key;
				
				if($ScriptBound.ContainsKey($ParamName)){
					$ParamValue = $ScriptBound[$ParamName]
				} else {
					$ParamValue = Get-Variable -Name $ParamName -Scope 1 -ValueOnly -EA SilentlyContinue 
				}
				
				$Params.$ParamName = $ParamValue
			};
			
			
			
			return $Params;
		}

		#CHeck if current users is administrator.
		function IsAdmin {
			#thanks to https://serverfault.com/questions/95431/in-a-powershell-script-how-can-i-check-if-im-running-with-administrator-privil
			$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
			$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
		}
		
		#Invoke logman and convert exit codes to powershell exceptions.
		function pslogman {
			$LogManOutput = logman @Args;
			if($LastExitCode){
				throw "LOGMAN_ERROR: $LastExitCode. Output:`r`n$LogManOutput"
			}
			
			if($Args[0] -eq 'query'){
				$Result = @();
				$InResult = $false;
				$LogManOutput | %{
					$Line = $_;
					if($Line -match '^-+$'){
						$InResult = $true;
						return;
					}
					
					
					if($InResult){
						if($Line.length -eq 0){
							$InResult = $false;
							return;
						}
						
						$Parts = $Line -split '[\s]+',4
						$Result += New-Object PsObject -Prop @{
												Name 		= $parts[0]
												Type 		= $parts[1]
												Status 		= $parts[2]
												SourceLine 	= $parts[3]
										}
					}
					
					
				}
				
				return $Result;
			} else {
				return $LogManOutput;
			}
			
			
		}

		#Converts bytes to human format.
		Function Bytes2Human {
			Param ($size)
			If     ($size -gt 1TB) {[string]::Format("{0:0.00} TB", $size / 1TB)}
			ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00} GB", $size / 1GB)}
			ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00} MB", $size / 1MB)}
			ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00} KB", $size / 1KB)}
			ElseIf ($size -gt 0)   {[string]::Format("{0:0.00} B", $size)}
			else {return $size}
		}

		#Convert seconds to human format
		Function Secs2Human {
			Param ($secs)
			If     ($size -gt 1TB) {[string]::Format("{0:0.00} TB", $size / 1TB)}
			ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00} GB", $size / 1GB)}
			ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00} MB", $size / 1MB)}
			ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00} KB", $size / 1KB)}
			ElseIf ($size -gt 0)   {[string]::Format("{0:0.00} B", $size)}
			Else {return $size}
		}
		
		#Convert human time to seconds
		Function Human2Secs {
			Param ($human)
			
			if($human -is [int]){
				return $human;
			}
			
			if(!$human){
				return;
			}
			
			$secs = @{
				y	= 31104000
				mo 	= 2592000
				w   = 604800
				d   = 86400
				h 	= 3600
				m 	= 60
				s 	= 1
			}
			
			if($human -match '(\d+)(\w+)'){
				$c = $secs[$matches[2]];
				
				if(!$c){
					throw "HUMAN2SECS_INVALID_INPUT: INVALID_UNIT $($matches[2])";
				}	
				
				$secs = ([int]$matches[1]) * $secs[$matches[2]];
				return $secs;
			} else {
				throw "HUMAN2SECS_INVALID_INPUT: $human";
			}	
			
			If     ($size -gt 1TB) {[string]::Format("{0:0.00} TB", $size / 1TB)}
			ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00} GB", $size / 1GB)}
			ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00} MB", $size / 1MB)}
			ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00} KB", $size / 1KB)}
			ElseIf ($size -gt 0)   {[string]::Format("{0:0.00} B", $size)}
		}

		#Set priority of current process
		Function SetPriorityClass {
			param($Priority)
			$Me = gwmi Win32_Process -Filter "ProcessId = $PID";
			
			if(!$Me){
				throw "EMPTY_CURRENT_PROCESSWMI";
			}
			
			$Priorities = @{
				Idle 		= 64
				BelowNormal = 16384 
				Normal 		= 32
				AboveNormal	= 32768
				High		= 128
				RealTime	= 256
			}
			
			$nd = $Me.SetPriority($Priorities[$Priority]);
		}

		#Run a com script and hanlde possible HResults...
		#Script will run you own scope, then, if you create some variable, it will survive just inside it.
		function RunCom {
			[CmdletBinding()]
			param(
				 [Parameter(Position = 0)]
				 $ScriptBlock
				,$IgnoreHResult = @()
				,[switch]$LogIgnored = $null
				,[Alias('LogMsg')]$LogMessage = $null

			)
			
			$OriginalScript = $ScriptBlock;
			try {
				$result = . $ScriptBlock
			} catch {
				#if was not found error...
				$Ex = $_.Exception;
				$Ignore = $false;

				if($IgnoreHResult -eq '*'){
					$Ignore = $true;
				} elseif( $Ex -match 'HRESULT: 0x([a-f0-9]+)'){
					$HResult = [convert]::ToInt32($matches[1],16);
					
					if($IgnoreHResult -Contains $HResult){
						$Ignore = $true;
					} 
					
				} else {
					$msg = @(
						"RunCom: Cannot determine HRESULT from current exception: $Ex"
						"Raised when ran following script:"
						$ScriptBlock	
						"-- end ---"
					) -Join "`r`n";
					
					log $msg;
					throw;
				}
			
				if($Ignore){
					if($LogMsg){
						$LogMsg = "This is just informational"
					}
				
					$msg = @(
						"COM Error: $ex"
						$LogMsg
						"Raised when ran following script:"
						"$ScriptBlock"
					) -Join "`r`n";
					
					if($LogIgnored){
						log $msg;
					} else {
						log -v $msg;
					}
					
					return;
				}
				
				throw $ex;	
			}
			
			return $result;
		}



		#Convert a string to base64
		function ToBase64 {
			param(
				[string]$string
			)
			
			return [Convert]::ToBase64String([Text.Encoding]::UNICODE.GetBytes($string))
		}

		#Converts from base 64 a string converted using ToBase64
		function FromBase64 {
			param (
				[string]$StringEncoded
				
			)
			
			return [Text.Encoding]::UNICODE.GetString([Convert]::FromBase64String($StringEncoded))
		}

		#Generates a encoded version of object to be transferred to another process, strings, et.
		function EncodeObject {
				param($object,$deep = 10)
				
				return  ToBase64 ([System.Management.Automation.PSSerializer]::Serialize(
													$object,$deep 
												)
								);
		}

		<#
			.SYNOPSIS
				Imports a storage exported with Export-SophieToolsStorage
		#>
		function DecodeObject {
				param($Encoded)
				
				[System.Management.Automation.PSSerializer]::Deserialize(
													(FromBase64 $Encoded)
												) 
		}



		#Start a powershell job and create all functions and other important data
		$JobPidMapping = @{};
		function StartJob {
			param($JobName,$Script, [object[]]$FunctionList = @(),[switch]$Force,$Data,[switch]$Process)
			
			if($JobName -isnot [string]){
				throw "INVALID_JOBNAME"
			}
			
			if(!$JobName){
				throw "MUST_DEFINE_JOBNAME";
			}
			
			$FullJobName = "SqlPerfCollectJob_"+$jobName;
			$Existing = gjb -Name $FullJobName -EA SilentlyContinue;
			if($Existing -and !$Process){
				
				if($force){
					log -v "Stopping existings jobs $FullJobName";
					KillJob $Existing;
				} else {
					throw "JOBNAME: ALREADY_EXISTS";
				}
				
			}
			
			#Get all functions...
			if($Functions){
				$Functions = gci Function:\ | ? { $FunctionList -Contains $_.Name  };
			} else {
				$Functions = $ScriptFunctions;
			}
			
			$ScriptString = $Functions | %{
				"function $($_.name){  
					$($_.Definition)
				}
				
				"
			}
			

			
			$ts = (Get-Date).toString("yyyyMMdd_HHmmssfff");
			$TemporaryInitScript 	= "$JobsPath\$JobName.initscript.ps1";
			$TemporaryPidFile 		= "$JobsPath\$JobName.pid.$ts.txt";
			
			log -v "Writing temporary init script to $TemporaryInitScript";
			$ScriptString > $TemporaryInitScript;
			log -v "	Done";
			
			$Params = $ScriptParammeters;
			
			$Data = @{
				script = $Script
				FullName = $FullJobName
				Name = $JobName
				DirectoryPath = $JobsPath
				AllVars = (gci variable:\)
				InitScript = $TemporaryInitScript;
				CustomData 	= $Data
				PidFile		= $TemporaryPidFile
				ProcessScript 	= $null
				ProcessDataFile	= $null		
			}
			
			log -v "Preparing Jobscript";
			$JobScript = {
				param($JobData,$IsEncoded = $false)
				
			
				
				$ErrorActionPreference 	= "Stop";
				$MyName 				= $JobData.Name;
				$ExcludeVars 			= @("ScriptLogFile","LogSource");
				$InitScript				= $JobData.InitScript;
				$RootJobPath			= $JObData.DirectoryPath;
				$TemporaryPidFile		= $JobData.PidFile;
				$ProcessScript			= $JobData.ProcessScript
				$ProcessDataFile		= $JobData.ProcessDataFile
				
				if(!$ProcessScript){
					"PID:$PID" > $TemporaryPidFile;
				}
				
				#Initializaing...
				. $InitScript;
				
				#Remove init script...
				Remove-Item $InitScript -force -EA silentlycontinue;
				
				if($ProcessScript){
					Remove-ITem $ProcessScript -force -EA silentlycontinue;
				}
				
				if($ProcessDataFile){
					Remove-Item $ProcessDataFile -force  -EA SilentlyContinue
				}
				
				if($ProcessScript){
					$LogSource		= "PROC:$MyName"
				} else {
					$LogSource		= "JOB:$MyName"
				}	
				
				$ScriptLogFile 	= "$RootJobPath\job_$Myname.log";
				if(Test-Path $ScriptLogFile){
					remove-item $ScriptLogFile;
				}
				log "Job started... Pid:$pid";
				
				log -v "Loading all variables";
				$JobData.AllVars | ? { $ExcludeVars -NotContains $_.Name }  | %{
					try {
						if(-not(Get-Variable -Name $_.Name -EA SilentlyContinue)){
							Set-Variable -Name $_.Name -Value $_.Value -Scope Global -force -EA SilentlyContinue;
						}
					} catch {
						
					}
				};
				
				log -v "Running job script";
				
				$FullJobScript = [scriptblock]::create($JobData.script);
				try {
					& $FullJobScript $JobData.CustomData
				} catch {
					log "FAILED: $_ | LineNum:$($_.InvocationInfo.ScriptLineNumber) SourceLine:`r`n$($_.InvocationInfo.Line)";
					throw;
				} finally {
					log -v "Script done";
				}
				
			} ;
			log -V "Done";
			
			if($Process){
				$TemporaryProcessScript 	= "$JobsPath\$JobName.process.ps1";
				$TemporaryDataFile 			= "$JobsPath\$JobName.process.xml";
				$Data.ProcessScript 	= $TemporaryProcessScript
				$Data.ProcessDataFile 	= $TemporaryDataFile
				
				log -v "Exporting to $TemporaryDataFile...";
				$Data | export-clixml $TemporaryDataFile;
				
					
				log -v "Writing temporary process file $TemporaryProcessScript";
					@(
						"`$Data = import-clixml $TemporaryDataFile"
						". { $JobScript } `$Data"
					) > $TemporaryProcessScript
				
				log -v "Starting process job";
				$NewProc = Start-Process -PassThru -WindowStyle Hidden powershell -ArgumentList @(
							'-ExecutionPolicy ByPass'
							'-NonInteractive'
							'-NoLogo'
							'-File'
							$TemporaryProcessScript 
						)
				log -v "Process $($NewProc.id) started...";
				return $NewProc;
			} else {
				$TheJob = Start-Job -Name $FullJobName -ScriptBlock $JobScript -ArgumentList $Data;
				
				while($true){
					log -v "Waiting job pid...";
					
					$PidContent = Get-Content $TemporaryPidFile -EA SilentlyContinue;
					
					if($PidContent -match 'PID:(\d+)'){
						$JobPid = $matches[1];
						$JobPidMapping[$TheJob.Id] = $JobPid;
						
						log -v "Job $JobName (Id = $($TheJob.Id)) using pid $JobPid";
						
						$PidDirs = mkdir "$JobsPath\pids" -force;
						
						$PidFilePath = "$PidDirs\$($TheJob.InstanceId).pid.txt";
						remove-item $TemporaryPidFile  -force;
						$JobPid >  $PidFilePath 
						break;
				}
				
				Start-Sleep -s 1;
			}
			}
			
			

			
			return $TheJob;
			
			
		}
		
		function KillJob {
			param($Job)
			
			if($Job -is [System.Diagnostics.Process]){
				$Job | Stop-Process -Force -EA SilentlyContinue;
				return;
			}
			
			$Jobid = $Job.Id;
			$Job = Get-Job -Id $JobId -Ea SilentlyContinue;
			
			
			if(!$job){
				return;
			}
			
			$PidPath = "$JobsPath\pids\$($Job.InstanceId).pid.txt";
			
			if($Job.state -eq 'running'){
				$JobPid = get-content $PidPath -ea silentlycontinue;
				
				if(!$JobPid){
					log "JOBPID_NOTFOUND: $($JobId)";
					return;
				}
				
				Stop-Process -Id $JobPid  -Force -EA SilentlyContinue;
			}
			
			remove-item $PidPath -force -EA SilentlyContinue;
			$job  | remove-job -force;
		}
		
		
		
		<#
			Standard Assync Collector.
			
				StdCollector = InvokeStdColletor CollectorName FuncName MaxTime
				
				-- Invokes the function in a loop by MaxTime
				-- Comunicates with main thread using return standard messages 
				-- A unique place to check if function completed.
					If yes, handle possiible erros or failures and/or restart again.
					If no, do nothing...
				
				
			object CreateAsyncCollector(Name,FunctionName,FunctonData,MaxRuntime)
				
				StartJob = 
					While RanTime < MaxRunTime 
						run FunctionName FunctionData
				
				GlobalListJbs += StartJob;
				
				
			CheckAsybcCollector(Object,Rerun)
			
				ForEachRunning Job
				
					Get status.
						
					
					Completed?
						If fail, throws error.
						Sucess? 
							Check if was a normal completed...
							If not, throws error.
						Log output.
						
					Not completed?
						Get output,
							Parse output type.
							If string, just print.
							If command, do the actions in main thread.
					
							
					If sucess,	
						Log output
						Must run again? Run.
						
					Yes, then:
						Get status
		
		#>
		
		
		
		#Get instance sql name from cluster...
		function InstanceName2ClusterName {
			param($InstanceName)
			
			if(!$ContainsFailoverClusterModule){
				return;
			}

			log -v "Searching sql server clustered resources..."
			$AllSqlResources = Get-ClusterResource | ? { $_.ResourceType -eq "Sql Server" -and $_.State -eq "Online" };
			log -v "	Onlined clustered:$($AllSqlResources.count)";
			
			if(!$AllSqlResources){
				return;
			}
			
			
			$InstanceResource = $null
			foreach($Res in $AllSqlresources){ 
				$P = $Res | Get-ClusterParameter -Name InstanceName; 
				if($p.Value -eq $InstanceName){
					$InstanceResource = $Res;
					break;
				}

			};
			
			if(!$InstanceResource){
				log -v "Instance resource not found for $InstanceName. Maybe is not clustered...";
				return;
			}
			
			$ServerName = @($InstanceResource | Get-ClusterParameter -Name VirtualServerName).Value;
			
			if(!$ServerName){
				log "Cannot retrieve ClusterParameter VirtualServerName from $($Res.Name)";
				return;
			}

			
			if($InstanceName -eq 'MSSQLSERVER'){
				$FullName = $ServerName
			} else {
				$FullName = "$ServerName\$InstanceName"
			}

			return $FullName;
		}
		
		
		#Get list of running instances
		function GetRunningInstances(){
			$SqlServers = @{}
			
			$ServiceInstanceFilter = @(
				"State = 'Running'";
			)

			#Generating WMI filter...
			if($SqlInstance){
				$InstanceNameFilter = @($SqlInstance | %{
					if($_ -eq 'MSSQLSERVER')
					{
						"Name = 'MSSQLSERVER' OR Name = 'SQLSERVERAGENT'"
					} else {
						"Name = 'MSSQL`$$_' OR Name = 'SQLAGENT`$$_'"
					}
					
				}) -Join " OR "	
				$ServiceInstanceFilter += "($InstanceNameFilter)"
			} else {
				$ServiceInstanceFilter += "(Name = 'MSSQLSERVER' OR Name LIKE 'MSSQL`$%' OR Name = 'SQLSERVERAGENT' OR Name LIKE 'SQLAGENT`$%')" 
			}

			$WmiFilter = $ServiceInstanceFilter -Join " AND ";

			$SQLInstanceServices = Get-WmiObject -Class Win32_Service -Filter $WmiFilter


			$SQLInstanceServices | %{

				if('SQLSERVERAGENT','MSSQLSERVER' -Contains $_.Name){
					$InstanceName = 'MSSQLSERVER';
				} else {
					$InstanceName = $_.Name -replace '(SQLAGENT|MSSQL)\$',''
				}
				
				if($InstanceName -eq 'MICROSOFT##WID'){
					log -v "Ignoring SqlServer instance $($_.Name) due begin used by Windows...";
					return;
				}
				
				<#
					@{
						INSTANCE_NAME = @{
								AgentService 	= Win32_Service
								SqlServer		= Win32_Service
								counters		= @{ agent = @(); sql = @() }
								InstanceName	= INSTANCE_NAME
							}
					}
					
				#>			
				$InstanceSlot = $SQlServers[$InstanceName];
				
				
				if(!$InstanceSlot){
					$InstanceSlot = @{};
					$SQlServers[$InstanceName] = $InstanceSlot;
					$CounterListSlot 	= @{
										agent 			= @()
										sql				= @()
										agenthistory	= @()
										sqlhistory		= @()
									}
					
					$instanceSlot.counters = $CounterListSlot
					$CounterListEx.instances[$InstanceName]	= $CounterListSlot
					$InstanceSlot.InstanceName = $InstanceName;
					
					$ClusterName = InstanceName2ClusterName $InstanceName
					
					if($ClusterName){
						$InstanceSlot.ServerAddress = $ClusterName;
					} else {
						if($InstanceName -eq 'MSSQLSERVER'){
							$InstanceSlot.ServerAddress = "."
						} else {
							$InstanceSlot.ServerAddress = ".\"+$InstanceName;
						}
					}
					
					
				}
				
				if($_.Name -like '*AGENT*'){
					$instanceSlot.AgentService = $_
				} else {
					$InstanceSlot.SqlServer = $_;
				}


			}

		
			return $SqlServers;
		}
		
		#Load list of monitored sql servers!
		#The target SQL Servers is our global variable the store a unifified list of target sql servers that script must work on.
		$TargetSqlServers = @();
		function LoadMonitoredSqlServers {
			$Script:TargetSqlServers = GetRunningInstances;
		}
		

		#Update the list of monitored process
		$TargetProcesses = @()
		function LoadTargetProcesses {
			$Script:TargetProcesses = @();

			
			$ExpectedProcessNames | %{
				$Procs = Get-Process $_ -EA SilentlyContinue;
				if($Procs){
					$Script:TargetProcesses += $Procs;
				}
			}

		}

		#Get a timestamped current file based on wildcard filter in some directory.
		#Function will manages the last current file and remove previous based on size.
		function GetCurrentFile {
			param($Directory,$Filter,$MaxSize = 5MB)
			
			if($MaxSize -eq $null){
				$MaxSize = 5MB;
			}
			
			
			#Transform SOMETHING*.EXT INTO SOMETHING.CURRENT.EXT
			$FullFilter = $Filter -replace '\.([^\.]+)$','.current.$1';
			
			log -v "	Current file original filter: $FullFilter. 'Current Filter' is: $FullFilter";
			
			#Current file is file where SqlPerfCollect keeps logging process...
			$CurrentFiles = @(gci "$Directory\$FullFilter" | sort CreationTime);
			
			log -v "Number of $FullFilter current files: $($CurrentFiles.count)";
			
			if($CurrentFiles){
			
				if($CurrentFiles.count -gt 1){
					log "There are multiple current files: $($CurrentFiles.count)"
					$CurrentFile = $CurrentFiles[-1];
					$LastFile = $CurrentFiles.count - 1;
					
					0..$LastFile | %{
						$FileItem = $CurrentFiles[$_];
						
						#Remove ".current"
						$FullFinalName = $FileItem.FullName -replace '\.current\.([^\.]+)$','.$1';
						log "	Will rename $($FileItem.Name) to $($FullFinalName)"
						Move-Item $FileItem $FullFinalName -force;
						log "	Done!";
					}
					
				} else {
					$CurrentFile = $CurrentFiles[0];
				}
				
				log -v "	Current file is: $CurrentFile";
				
				#Get size...
				if($CurrentFile.Length -ge $MaxSize){
					log -v "		File max size reached: $($CurrentFile.Length)"
					
					#Renamte it...
					$FullFinalName = $CurrentFile.FullName -replace '\.current\.([^\.]+)$','.$1';
					log -v "		Renaming to $FullFinalName";
					try {
						Move-Item $CurrentFile $FullFinalName;
					} catch {
						log "Error when moving process current file $CurrentFile to $($FullFinalName): $_";
						$Guid = [Guid]::NewGuid().Guid;
						$RandomName = $CurrentFile.FullName -replace '\.current\.([^\.]+)$',"$Guid.`$1"
						log "Will try move to a random name"
						try {
							Move-Item $CurrentFile $RandomName -force;
							log "	Sucess!"
						} catch {
							log "	Fail also: $_"
						}
						
					}
					
					$TheCurrentFile = $null;
				} else {
					$TheCurrentFile = $CurrentFile.FullName;
				}
			}
			
			#If not have current file, create a new empty...
			if(!$TheCurrentFile){
				$ts = (Get-Date).toString("yyyyMMdd_HHmmss");
				$NewFileName = $Filter -replace '\.([^\.]+)$',"$ts.current.`$1" -replace '[\*\?]','';
				$TheCurrentFile = "$Directory\$NewFileName";
			}
			
			return $TheCurrentFile;
		}


		#Export settings files
		function ExportSettings {
			param($Settings)
			
			$SettingsCurrent = GetCurrentFile -Directory $SettingsLogDirectory -Filter "settings_*.xml" -MaxSize 10MB;
			
			try {
				[object[]]$CurrentSettings = Import-CliXml $SettingsCurrent;
			} catch {
				log -v "Failed import current clixml settings $SettingsCurrent due to error: $_";
			}
			
			if(!$CurrentSettings){
				[object[]]$CurrentSettings = @();
			}
			
			$CurrentSettings += $Settings;
			
			log -v "Writing to setting file at $SettingsCurrent"
			$CurrentSettings | Export-CliXml $SettingsCurrent;
			
		}	

		#Export event
		function ExportEvents {
			param([hashtable]$Events, $FilePrefix = "events")
			
			$Events.pid 		= $PID;
			$Events.LogSource 	= $LogSource
			
			$CurrentFile = GetCurrentFile -Directory $InternalLogDirectory -Filter "$($FilePrefix)_*.xml" -MaxSize 20MB;
			
			try {
				[object[]]$CurrentEvents = Import-CliXml $CurrentFile;
			} catch {
				log -v "Failed import current clixml settings $CurrentFile due to error: $_";
			}
			
			if(!$CurrentEvents){
				[object[]]$CurrentEvents = @();
			}
			
			
			$CurrentEvents += $Events;
			
			$Events.LogTs		= (Get-Date)
			log -v "Writing events to  $CurrentFile"
			$CurrentEvents | Export-CliXml $CurrentFile;
			
		}	


		#Enforce directory maximum size on some directory.
		function CheckDirSize(){
				param($Directory,$Filter = '*',$MaxSize,$Action,$FilterExclude = @())
				
			
				if(!$MaxSize){
					return;
				}
				

				$AllDirs = @();
				
				$Directory | %{
					if(-not(Test-Path $_)){
						return;
					}
				
					$AllDirs += $_;
				}
				
				if(!$AllDirs){
					return;
				}


				#Validate size...
				$AllFiles 	=  $AllDirs | % { 
					log -v "Getting files from path $_ (excluding: $FilterExclude)";
					gci $_ -Filter * -recurse
				} | ? { 
					$Name = $_.Name;
					
					if($_.PsIsContainer){
						return $false;
					}
					
					#exclude?
					if($FilterExclude){
						foreach($f in @($FilterExclude)){
							if($Name -Like $f){
								return $false;
							}
						}
					}

	
					foreach($f in @($Filter)){
						if($Name -Like $f){
							return $true;
						}
					}
				} | sort LastWriteTime;
				
				$TotalSize 	= ($AllFiles | Measure-Object -Sum -Property Length).Sum;
				log -v "Current size of all directories: $(Bytes2Human $TotalSize) (Max: $(Bytes2Human $MaxSize))"
				

				if($TotalSize -gt $MaxSize){
					$msg = "";
					
					if($AllDirs.count -eq 1){
						$msg = "[Directory: $($AllDirs[0])]";
					}
					
					$msg += "Total size is $(Bytes2Human $TotalSize). Max is: $(Bytes2Human $MaxSize).";
				
				
					log -v $msg;
					$Sum = 0;
					$Size2Remove = $TotalSize - $MaxSize;
					
					if($Action -eq 'oldremove'){
						log -v "	Need remove $(Bytes2Human $Size2Remove) of files... Electing..."
						$Fi = 0;
						[object[]]$RemovedFiles = @()
						[object[]]$Faileds = @();
						while($sum -lt $Size2Remove -and $fi -lt $AllFiles.length){
							$ElegibleFile = $AllFiles[$fi];
							$fi++;
						
							try {
								$ElegibleFile | Remove-Item -force;
								$RemovedFiles += $ElegibleFile;
								$sum += $ElegibleFile.Length;
							} catch {
								log "Failed remove file $($ElegibleFile): $_";
								$Faileds += @{
										File = $ElegibleFile
										Error = $_
									}
								
							}
						}
						
						#If after read files sum was not grather than size, then some crucial error to delete lot of files happebs...
						if($sum -lt $Size2Remove){
							$Dirs = $AllDirs -Join "`r`n"
							log "WARNING: Script cannot clean size due to some problem when removing. Check previous messages. Need remove $(Bytes2Human $Size2Remove) but only $(Bytes2Human $sum) was removed. Directories:`r`n$Dirs"
						}
						
						$FilesToRemoveString = @($RemovedFiles | %{ "`t`t`t"+$_.Name+" ($(Bytes2Human $_.Length))" }) -Join "`r`n";
						$FilesFailedString = @($Faileds | %{ "`t`t`t"+$_.File.Name+" ($(Bytes2Human $($_.File.Length)))" }) -Join "`r`n";
						
						log -v "	Following files was removed:`r`n$FilesToRemoveString";
						
						if($Faileds){
							log -v "	Following files failed:`r`n$FilesFailedString";
						}


						if(!$INTERNAL_DATA.RemovedFiles){
							$INTERNAL_DATA.RemovedFiles += @();
						}
						
						$INTERNAL_DATA.RemovedFiles += @{
								Reason 		= "MaxDirSize"
								TotalSize	= $TotalSize
								MaxSize		= $MaxSize
								Size2Remove	= $Size2Remove
								Dirs 		= $AllDirs
								RemovedSuccess 	= $RemovedFiles
								RemoveFailed	= $Faileds
							}
					}
					
					if($Action -eq 'error'){
						StopDataCollectorSet
						throw "MAX_TOTALSIZE_REACHED: TotalSize: $(Bytes2Human $TotalSize) Max:$(Bytes2Human $MaxSize)"
					}

				}
				
		}

		#Enforce collect age on some directory.
		function CheckCollectAge {
			param($Directory,$Filter = '*',$MaxTime,$Action,$FilterExclude = @())
			
			if(!$MaxTime){
				return;
			}
			
			if(-not(Test-Path $Directory)){
				return;
			}


			$DirectoryFilter = $Directory;
			if($Filter){
				$DirectoryFilter += '\'+$Filter;
			}	
			
			$ExpectedOldestTime = (Get-Date).addSeconds(-$MaxTime);
			
			log -v "Checking files older than $ExpectedOldestTime ($MaxTime sec ago) on $Directory"
			
			$OldestFiles = gci $Directory -Filter * | ? { 
					$_.LastWriteTime -lt $ExpectedOldestTime 
					$Name = $_.Name;
					
						#exclude?
						if($FilterExclude){
							foreach($f in @($FilterExclude)){
								if($Name -Like $f){
									return $false;
								}
							}
						}

						foreach($f in @($Filter)){
							if($Name -Like $f){
								return $true;
							}
						}	
			} | sort CreationTime;
			
			if(!$OldestFiles){
				return;
			}
			
			log "There are files last modified older than $MaxTime seconds ($ExpectedOldestTime)"
			
			if($Action -eq 'error'){
				StopDataCollectorSet
				throw "MAX_TIME_REACHED: ExpectedOldestTime:($ExpectedOldestTime) ($MaxTime seconds ago)"
			}
			
			
			if($Action -eq 'oldremove'){
				$FilesToRemoveString = @($OldestFiles | %{ "`t`t`t"+$_.Name+" LastModified:$($_.LastWriteTime)" }) -Join "`r`n";
				
				log "	Following files will be removed:`r`n$FilesToRemoveString"
				$OldestFiles | Remove-Item -force;
			}
		}


		#Check if verbose was enabled in runtime...
		function CheckVerboseEnabled {
			$VerboseLogFile = "$DirectoryPath\Log.parameters.txt";
			
			if($VerboseSource -eq 'VerbosePreference'){
				return;
			}
			
			$VerboseLogFileContent = @(Get-Content -EA SilentlyContinue $VerboseLogFile);
			
			if($VerboseLogFileContent[0] -eq 'Verbose'){
				if(!$IsVerboseEnabled){
					$Script:IsVerboseEnabled = $true;
					$Script:VerbosePreference = "Continue";
					$VerboseSource	= "Runtime";
					log "Verbose mode enabled from runtime";
				}
			} else {
				if($IsVerboseEnabled){
					$Script:VerbosePreference = "SilentlyContinue";
					$Script:IsVerboseEnabled = $false;
					$VerboseSource	= $null;
					log "Verbose mode disabled from runtime";
				}
			}
			
		}

		#Do some checks.
		$LastMainChecks = $null;
		function DoChecks {
			if($LastMainChecks){
				#Elapsed 
				$Elapsed  = (Get-Date) - $LastMainChecks;
				
				log -v "Last main check: $LastMainChecks | Elapsed: $Elapsed | Frequency seconds: $CheckFrequencySeconds";
				
				if($Elapsed.TotalSeconds -lt $CheckFrequencySeconds){
					log -v "	No time to check yet."
					return;
				}
				
				log -v "Its time to check!"
			}
			
			$GlobalCheckDirs = @();
			$GlobalCheckDirsTime = @();
			
			@($COLLECTS.Values) | %{
				$DirPath 	= $_.Path;
				$MaxSize 	= $_.MaxSize;
				$Excludes	= $_.Excludes;
				$ExcludeGlobal = $_.ExcludeGlobal;
				
				log -v "Checking directory limit on $DirPath"
				
				if($ExcludeGlobal){
					log -v "	Global check disabled on this directory";
				} else {
					$GlobalCheckDirs += $DirPath;
				}
				
				if(!$MaxSize){
					log -v "	MaxSize disabled on this directory";
					return;
				}
				
				log -v "	MaxSize is: $MaxSize";
				
				
				CheckDirSize -Directory $DirPath -FilterExclude $Excludes -MaxSize $MaxSize -Action $OnMax;
				
				if($MaxCollectTimeSeconds){
					log -v "	Enforcing max collect time"
					CheckCollectAge -Directory $DirPath -FilterExclude $Excludes -MaxTime $MaxCollectTimeSeconds -Action $OnMax
				}
				
				

				
			}
				
			#Enforce max size on all directoriees sum!
			#Check size of all directories with some logging...
			if($MaxCollectSize -ne $null -and $GlobalCheckDirs){
				log -v "Checking global max size on all directorires (Total: $($GlobalCheckDirs.count))";
				CheckDirSize -Directory $GlobalCheckDirs -FilterExclude $CheckSizeExcludes -MaxSize $MaxCollectSize -Action $OnMax
			}
			
			
			$Script:LastMainChecks = (Get-Date);
		}

		#Check if monitored processes add or dead.
		function CheckProcessUpdates {
			$SomeUpdated = $false;
			
			$TargetProcesses | %{
				$CurrentMonitored = $_;
				$CurrentStartTime = $_.StartTime;
				$CurrentName = $_.name;
				
				$Dead = $false;
				
				#Check if exists...
				$Updated = Get-Process -Id $CurrentMonitored.Id -EA SilentlyContinue;
				
				if(!$Updated){
					$Dead = $true;
				}
				
				if($CurrentName -ne $Updated.Name -or $CurrentStartTime -ne $Updated.StartTime){
					$Dead = $true;
				}
				
				if($Dead){
					$SomeUpdated = $true;
					log "Process Id $($CurrentMonitored.Id) ($($CurrentMonitored.name)) not exists anymore" -Buffer LASTENVCHANGE_REASONS;
				}
			}
			
			#check if appeared a new one...
			$MonitoredIds = @($TargetProcesses | %{$_.Id});
			if($ExpectedProcessNames){
				$ExpectedProcessNames | %{
					$ExistingProceses = Get-Process -Name $_ -EA SilentlyContinue | ? { $MonitoredIds -Notcontains $_.Id };
					
					if($ExistingProceses){
						$SomeUpdated = $true;
						$ExistingProceses | %{
							log "New process $($_.Id) ($($_.name)) found!" -Buffer LASTENVCHANGE_REASONS
						}
					}		
				}
			}
			
			return $SomeUpdated;
			
		}
		
		#Check for instance updates...
		#Other functions must fill the CurrentSQLServers global var to ask this function to compare the "current" view...
		#todo: better way to manage global list of instances to check if some update occurred...
		function CheckSqlInstancesUpdates {
			$LastSQLServers = GetRunningInstances;
					
			$SomeUpdate = $false;
			
			#TODO: CHECK SQL AGENT CHANGES...
			
			
			#Check for changeds or news...
			foreach($Last in $LastSQLServers.GetEnumerator()){
				$InstanceName 	= $Last.key;
				$ExistingTarget = $TargetSqlServers[$InstanceName]
				$LastPid 		= $Last.value.SqlServer.ProcessId;

				
				#Current instance not exists? Then this was update...
				if(!$ExistingTarget){
					log "New instance added: $InstanceName" -Buffer LASTENVCHANGE_REASONS;
					$SomeUpdate = $true;
					continue;
				}
				
				
				$PrevPid = $ExistingTarget.SqlServer.ProcessId;
				if($PrevPid -ne $LastPid){
					log "Instance $InstanceName changed pid ($PrevPid --> $LastPid)" -Buffer LASTENVCHANGE_REASONS;
					$SomeUpdate = $true;
				}
			}
			
			#Check for removeds (downs, stopped, killed, etc.)...
			foreach($Target in $TargetSqlServers.GetEnumerator()){
				$InstanceName = $Target.key;
				
				$ExistingOnLast = $LastSQLServers[$InstanceName];
				
				if(!$ExistingOnLast){
					log "Instance down $InstanceName" -Buffer LASTENVCHANGE_REASONS;
					$SomeUpdate = $true;
				}
			}

			return 	$SomeUpdate;
		}
		
		
		#This function check if some monitored process/service has change its pid or stopped or included.
		[string[]]$LASTENVCHANGE_REASONS = @()
		function CheckEnvironmentChanges {
			$SomeUpdate = $false;
			
			$Script:LASTENVCHANGE_REASONS = @();
			if(CheckSqlInstancesUpdates){
				log -v "Detected sql instances updates..."
				$SomeUpdate = $true;
			}
			
			#Check for monitored processes
			if(CheckProcessUpdates){
				log -v "Detected  process updates..."
				$SomeUpdate = $true;
			}
			
			return $SomeUpdate;
		}
		
		#Check if somehting changed like a new monitored process appears or sql instance changed its pid.
		$LastChangecheck = $null;
		function DoCheckEnvChanges {
				if(!$CheckChangesFrequencySeconds){
					log -v "No env changes will be checked because it is disable due  CheckChangesFrequencySeconds is 0"
					return;
				}
		
				if($LastChangeCheck){
					$ElapsedCheck = ((Get-Date) - $LastChangeCheck);
					
					log -v "Last env check: $LastChangeCheck | Elapsed: $ElapsedCheck | Frequency seconds: $CheckChangesFrequencySeconds";
					
					if($ElapsedCheck.totalSeconds -lt $CheckChangesFrequencySeconds){
						log -v "	Not time to check env changes yet";
						return $false
					}
				}
				
				log -v "	Its time to check for env changes...";
				$Script:LastChangeCheck = (Get-Date);
				if(CheckEnvironmentChanges){
					log "Change were detected... Invoking collection configuration setup.";
					UpdateCollectionConfiguration
					return $true;
				} else {
					log -v "No changes detected...";
				}
				
				return $false;
		}
		
		#Manges the setup of collection every time it need be setup.
		function SetupCollection {
			param([switch]$FirstTime)
			
			$SETTINGS_LOG = @{
				Ts					= (Get-Date)
				PerfCountersFile 	= $PerfCountersFile
				Parameters 			= (GetParameters)
				procs				= $procs
				LastChangeReason	= $LASTENVCHANGE_REASONS
				Collects			= $COLLECTS
				DataCollectors		= $DATACOLLECTORS
				CollectorSetup		= @{}
				ProgressFrequency	= $ProgressFrequencySeconds
			}

			#Load list of all SQL Running instances elegibles to we monitor
			log "Loading list of target SQL Servers";
			LoadMonitoredSqlServers
			log "	Done. Instance count: $($TargetSqlServers.count)"
			
			#Load list of all SQL Running instances elegibles to we monitor
			log "Loading list of target processes";
			LoadTargetProcesses
			log "	Done. Process count: $($TargetProcesses.count)"
		
			$SETTINGS_LOG.TargetSqlServers = $TargetSqlServers;
				
			Log "Running prexecutions stepts...";
			$PreExecutionData = @{}
			
			foreach($PrexecFunction in $PREXECS){
				log "Executing prexec $PrexecFunction"
				$PreExecutionData[$PrexecFunction] = & $PrexecFunction;
			}
			
			
			log "Setting up collections";
			foreach($Collect in $ACTIVE_COLLECTS.GetEnumerator()){
				$Name 		= $Collect.key;
				$Config		= $Collect.value;
				$SetupFunc 	= $Config.SetupFunc;
				
				$CollectSetupLog = @{};
				$SETTINGS_LOG.CollectorSetup[$Name] = $CollectSetupLog
				
				if($SetupFunc){
					log -v "Setting up collect $Name";
					& $SetupFunc $Config $CollectSetupLog $FirstTime.IsPresent $PreExecutionData;
				}
				
			}
			
			log "Exporting updated settings file";
			$SettingsObject =  New-Object PsObject -Prop $SETTINGS_LOG
			ExportSettings $SettingsObject;
			
		}
		
		function UpdateCollectionConfiguration {
			log "(Re)Setting up collector due to changes in environment...";
			SetupCollection
			log "	Done!"
		}
		
		#Do some cleanup tasks.
		function DoCleanups {
			param($MaxRunTime = 2000)
			
			log -v "Cleanup orphan pid files...";
			$PidFiles = "$JobsPath\pids";
			
			$Start = (Get-date);
			$AllFiles = gci $PidFiles\*.pid.txt -EA SilentlyContinue;
			$TotalFilesChecked = 0;
			$TotalRemoved = 0;
			foreach($file in $allFiles){
				$JobId 	= $File.Name.replace('.pid.txt','');
				$JobPid = Get-Content -EA SilentlyContinue $file.FullName;
				$TotalFilesChecked++;
				
				$Elapsed = (Get-Date) - $Start;
				if($Elapsed.totalMilliseconds -gt $MaxRunTime){
					log -v "Ending cleanup due to expiration max runtime: $Elapsed | TotalChecked: $TotalFilesChecked | Removed:$TotalRemoved";
					break;
				}
				
				#Exists process with this pid?
				if($JobPid){
					$proc = Get-Process -EA SilentlyContinue -Id $JobPid
					
					if(!$proc){
						Remove-Item $file.FullName -force -EA SilentlyContinue;
						$TotalRemoved++;
						continue;
					}
				}
				
				#Job still exists?
				$Job = gjb | ? { $_.InstanceId -eq $JobId }
				
				if(!$Job){
					Remove-Item $file.FullName -force -EA SilentlyContinue;
					$TotalRemoved++;
					continue;
				}
				
			}	
		}
		
		function StartProgressMonitoring {
			
			$MonitoringData = @{
						 ParentProc = @{
								Id = $pid
								StartTime = (Get-Process -Id $pid).StartTime
							}
						 MaxRuntime = $MaxScriptRuntimeSeconds
					};
					
				$MonitoringJob = StartJob -Process Monitoring {
					param($p)
					
					$MaxRun = $p.MaxRuntime + 30;
					$Parent = $p.ParentProc

					$Process = Get-Process -Id $Parent.Id -EA SilentlyContinue;

					if($Process -and $Process.StartTime -ne $Parent.StartTime){
						return;
					}
					
					#If not max runtime, script do not stop due to maxruntime...
					if($MaxScriptRuntimeSeconds){
						$MustStop = $true;
					} else {
						$MustStop = $false;
					}
					
					$Reason = "EXPIRED_MAXRUNTIME";
					
					log "Waiting for $MaxRun seconds for process $($Parent.id)";
					$ElapsedSeconds = 0;
					$StartTime = Get-Date;
					while($ElapsedSeconds -lt $MaxRun){
						log -v "Sleeping for $ProgressFrequencySeconds secs.";
						Start-Sleep -s $ProgressFrequencySeconds;	
						
						if(!(CheckProgress)){
							log "Main process not progredding, we will stop it";
							$Reason  = "NOT_PROGREDDING";
							$MustStop = $true;
							$ProgressFrequency = $ProgressFrequencySeconds
							break;
						}
						
						if($Process.HasExited){
							log -v "Main process exited. Nothing more to do";
							ExportEvents -File "monitoring" @{
									Name		= "MainProcessExited"
									Ts 			= (Get-Date)
									Reason		= $null 
								}
							return;
						}
						
						$ElapsedSeconds = ((Get-Date) - $StartTime).totalSeconds;
						CheckVerboseEnabled
					}

					
					#If after maxrun parent job still running, then this is incorrect...
					if($MustStop){
						log "Stopping main process. Check previous for reason!";
						$Process | Stop-Process -force;
						
						ExportEvents -File "monitoring" @{
								Name		= "MainForcedStop"
								Ts 			= (Get-Date)
								Reason		= $Reason 
							}
					}
					
					log "Process $($Process.Id) exited";
					
				} -Force -Data $MonitoringData
				
				return $MonitoringJob;
		}
		
		#update progress info
		$LastProgressUpdate = $null
		function UpdateProgress {
			
			if($LastProgressUpdate){
				$Elapsed = (Get-Date) - $LastProgressUpdate;
				
				log -v "Progress elapsed: $Elapsed";
				
				if($Elapsed.TotalSeconds -lt $ProgressFrequencySeconds){
					log -v "No time to check progress yet";
					return;
				}
				
				$LastProgressUpdate = Get-Date;
			}
			
			$ProgressInfo = New-Object PsObject -Prop @{
					 Ts = (Get-Date)
				}
				
			log -v "Updating progress info";
			$ProgressInfo | Export-CliXml $ProgressFile -Force;
			log -v "	Done!";
		}
		
		$ProgressTries = 0;
		function CheckProgress {
			try {
				$Progressinfo = import-clixml $ProgressFile;
				$ProgressTries = 0;
			} catch {
				log "Error loading progress file: $_";
				
				if($ProgressTries -ge 3){
					log "Attempt to get progress info $ProgressTries times but not possible due to previous errors";
					return $false;
				}
				
				$Script:ProgressTries++;
				return $true;
			}
			
			$LastProgressReport = $ProgressInfo.Ts;
			$ElapsedReport = (Get-Date) - $LastProgressReport;
			$ProgressMaxElapsed = $ProgressFrequencySeconds + 20;
			
			log -v "Last Progress Report: $($LastProgressReport) | Elapsed:$ElapsedReport | Max:$ProgressMaxElapsed";
			
			if($ElapsedReport.totalSeconds -gt $ProgressMaxElapsed){
				log "Progress expired. Max: $ProgressFrequencySeconds | Elapsed Progress Report: $ElapsedReport (on: $LastProgressReport)";
				return $false;
			}
			
			return $true;
		}
		
		
		function DoInternalCollect {
			log -v "Doing internal collect...";
			
			if($INTERNAL_DATA.count){
				ExportEvents -file "InternalEvents" @{
						InternalData = $INTERNAL_DATA
					}
			}
			
			$Script:INTERNAL_DATA = @{};
		}
		

	### HELP FUNCTIONS ON DATA COLLECTOR SET
		function StartDataCollectorSet {
			param([string[]]$Include = @(),[string[]]$Exclude = @())
		
			$DATACOLLECTORS.GetEnumerator() | %{
				$CollectorName = $_.key;
				$ComCollector = $_.value;
				
				if($Exclude -and $Exclude -Contains $CollectorName){
					return;
				}
				
				if($Include -and -not($Include -Contains $CollectorName)){
					return;
				}
			
				#If not running, start.
				if($ComCollector.status -ne 1){
					write-debug "Starting collector $CollectorName";
					log -v "Starting collector $CollectorName";
					RunCom -IgnoreHResult 0x800710E0 {
						$ComCollector.start($true)
					} -LogIgnored;
					log -v "	Success!";
				} else {
					log -v "	Already running"
				}
			}
		}
		
		function StopDataCollectorSet {
			param([string[]]$Include = @(),[string[]]$Exclude = @())
		
			$DATACOLLECTORS.GetEnumerator() | %{
				$CollectorName = $_.key;
				$ComCollector = $_.value;
				
				if($Exclude -and $Exclude -Contains $CollectorName){
					return;
				}
				
				if($Include -and -not($Include -Contains $CollectorName)){
					return;
				}
			
				#If not stopped, stop it.
				if($ComCollector.status -eq 1){
					log -v "Stopping collector $CollectorName";
					write-debug "Stopping collector $CollectorName";
					RunCom -IgnoreHResult 0x80300104 { 
						$ComCollector.stop($true);
					}
					log -v "	Success!";
				} else {
					log -v "	Already stopped"
				}

			}
		}


	
	### FUNCTIONS IMPLEMENT PROCESS COLLECT
		
		#Do the collection of process and threads.
		function CollectProcess {
			param($Directory)
			

			#Current file is file where SqlPerfCollect keeps logging process...
			$LogFile = GetCurrentFile -Directory $Directory -Filter "process_*.csv" -MaxSize $ProcessLogMaxSize;
				
			log -v "Running Get-Process and exporting to $LogFile";
			$CollectTs = (Get-Date).toString("yyyyMMdd HH:mm:ss");
			$TsProp = @{N="Ts";E={$CollectTs}};
			$RawP = Get-process;
			$p = $RawP | select   $TsProp, `													
										id,name,WorkingSet64,StartTime,PagedMemorySize64,PeakPagedMemorySize, `
										TotalProcessorTime,UserProcessorTime,PrivilegedProcessorTime,VirtualMemorySize64, `
										SessionId,PrivateMemorySize64,PrivateMemorySize
			
			$p | Export-Csv $LogFile -Append -Force;
			
			if($CollectThreads){
				log -v "	Threads collection enabled...";
				#Current file is file where SqlPerfCollect keeps logging process...
				$LogFile = GetCurrentFile -Directory $Directory -Filter "threads_*.csv" -MaxSize $ProcessLogMaxSize;
			
			
				$CollectTs = (Get-Date).toString("yyyyMMdd HH:mm:ss");
				$TsProp = @{N="Ts";E={$CollectTs}};
				$PidProp = @{N="ProcessId";E={$ProcessId}};
				
				log -v "	Filtering elegible threads..."
				$ProcessThreadsFilter = @('sqlservr')
				
				$Threads = $RawP | ? {  $ProcessThreadsFilter -Contains $_.Name } | ? { $_.Threads }  | %{ $ProcessId = $_.Id; $_.Threads | select $TsProp,$PidProp,* };
				$Threads  | Export-Csv $LogFile -Append -Force;
			}
			
			log -v "	Done!";
		}

		#Encapsulate logic to invoke process collect based on its frequency, sync or async
		#Also, will check last collect.
		$LastProcessCollect = $null;
		function InvokeProcessCollect {

			#Process collect and validation...
			if($LastProcessCollect){
				$Elapsed = ((Get-Date) - $LastProcessCollect);
					
					log -v "Last process collect: $LastProcessCollect | Elapsed: $Elapsed | Frequency seconds: $ProcessLogSeconds";
					
					if($Elapsed.totalSeconds -lt $ProcessLogSeconds){
						log -v "	Not time to collect process yet";
						return;
					}
			}
		
			log -v "Collecting process info..."
			CollectProcess -Directory $ProcessLogDirectory
			$Script:LastProcessCollect = Get-Date;
		}

		#Start powershell job to collect process...
		function StartProcessCollectJob {
			
			StartJob ProcessCollect {
					$SleepTime = $ProcessLogSeconds/2;
					
					if($SleepTime -lt 1){
						$SleepTime = 1;
					}
					
					$StartRun = (Get-date);
					
					
					log "Starting process collect on this job. MaxRunTime is $ProcessJobMaxRuntimeSeconds secs"
					
					while($true){
						InvokeProcessCollect
						
						CheckVerboseEnabled
						
						log -v "Starting process collect sleep by $SleepTime secs"
						start-sleep -s $SleepTime;
						
						$Elapsed = (Get-Date) - $StartRun;
						
						if($Elapsed.totalSeconds -ge $ProcessJobMaxRuntimeSeconds){
							log "Job ending due to MaxRunTime!";
							break;
						}
					}
					
					return "NORMAL_END:MAXRUNTIME";
				}  -Force
		}
		

		#Entry point for process collect.
		#Will start correct routines based on configuration...
		$ProcessJob = $null;
		function DoProcessCollect {
			
			if(!$ProcessLogSeconds){
				log -v "No process collect due to ProcessLogSeconds is 0"
				return;
			}
			
			if($ProcessLogJob){
				#Started a process job?
				if(!$ProcessJob){
					log -v "	NO process collect job exists... Starting a new one..."
					$Script:ProcessJob = StartProcessCollectJob
					log -v "	Process collect job started successfully!";
				}
				
				#Check job status...
				if($ProcessJob.state -eq "Failed"){
					log "Process job appears failed... Check next log messages";
					$output = $ProcessJob | rcjb
					log "Process job output: $output";
					$removed = $ProcessJob | rjb;
					
					throw "FAILED_PROCESSJOB: $output";
				}
				elseif($ProcessJob.State -eq "Completed"){
					log -v "Process job appears completed";
					$output = $ProcessJob | rcjb
					
					if($output -eq "NORMAL_END:MAXRUNTIME"){
						log -v "Completed due to expired runtime. This is normal... Restarting job...";
						$Script:ProcessJob = StartProcessCollectJob
						log -v "	Success...";
					} else {
						throw "UNEXPECTED_PROCESSCOLLECT_OUTUT: $output";
					}
				}
				
			} else {
				#Invoke on this current powershell session...
				InvokeProcessCollect
			}

			return;
		}


	### functions implement PERF COUNTERS COLLECTOR
		
		#Get counters of a specific process
		$PROCESS_COUNTERS_MAPPING = @{};
		function GetProcessCounters {
			param([int]$id)
			
			# We would like \Process(Instance)\* form to get all counters, because would be more simple...
			# But, for collect data for a specif process, we must specify each counter name...
			# This is because  a bug mentioned on this forum:
			# Ref: https://social.technet.microsoft.com/Forums/en-US/cc5a3a9b-9517-4346-a114-aa5d23c1cf92/bug-user-defined-perfmon-data-collector-set-cannot-capture-data-just-from-one-process-object?forum=perfmon
			# Due to this bug, we need build the list of all counters  that we want collect for each process...
			# I dont know if this bug was fixed in some Windows version. But because we want this script be more compatible possible, we will use this method.

			#First, lets get list off all counters in category "Process"
			$c = New-Object System.Diagnostics.PerformanceCounterCategory("Process")

			log -v "	Querying WMI raw data to find process instance for process = $($id)";
			$Counters = gwmi Win32_PerfRawData_PerfProc_Process | ? {$_.IdProcess -eq $id};
			log -v "		Done!";
			
			$CounterInstance = $Counters.Name;
			
			if(!$PROCESS_COUNTERS_MAPPING[$id]){
				$PROCESS_COUNTERS_MAPPING[$id] = New-Object PsObject -Prop @{
						ProcessId 		= $null
						CounterInstance	= $null
						Arguments		= $null
					}
			}
			
			$PROCESS_COUNTERS_MAPPING[$id].ProcessId = $id;
			$PROCESS_COUNTERS_MAPPING[$id].CounterInstance = $CounterInstance;
			$PROCESS_COUNTERS_MAPPING[$id].Arguments = $null;
			
			$ProcessCounterList = @();
			$HistoryList		= @()
			$HistoryCounters = @(
					'% Processor Time'
					'% User Time'
					'% Privileged Time'
					'Virtual Bytes'
					'Working Set - Private'
					'Working Set Peak'
					'Page Faults/sec'
					'Page File Bytes'
					'IO Read Bytes/sec'
					'IO Write Bytes/sec'
				)
			
			if($c.InstanceExists($CounterInstance)){
				log -v "	Getting list of counters..."
				$ProcessCounters = $c.GetCounters($CounterInstance)
				
				log -v "	Iterating over counter list and building final list...";
				$ProcessCounters | %{
					$CounterName = "\Process($CounterInstance)\$($_.CounterName)";
					
					$ProcessCounterList += "\Process($CounterInstance)\$($_.CounterName)";
					
					
					if( $HistoryCounters -Contains $_.CounterName ){
						$HistoryList += $CounterName
					}
				}
			}
			
			return @{
					CounterList 		= $ProcessCounterList 
					CounterListHistory	= $HistoryList 
					CounterInstanceName	= $CounterInstance
				}
		}	

		#Get a mapping of process to counter instance
		function GetProcessCounterMapping {
			param([switch]$NoCheckExisting)
			

			$Mapping = @();
			$PROCESS_COUNTERS_MAPPING.GetEnumerator() | %{
				$Id = $_.key;
				$Proc = Get-Process -Id $Id -EA SilentlyContinue
				$WmiProc = gwmi -Query "SELECT ProcessId,CommandLine FROM Win32_Process WHERE ProcessId = $Id" 
				$Map = $_.value;
				
				if($WmiProc){
					$Map.Arguments = $WmiProc.CommandLine
				}
				
				if($Proc -or !$NoCheckExisting){
					$Mapping += $Map;
				}
			}
			
			return $Mapping;
		}

		#this function update the counters associated with sql server instances
		function UpdateSqlInstancecounters {
			param([switch]$IncludeHistory)
			
			if(!$TargetSqlServers){
				log "WARNING: No SQL instances elegible to monitor... Data collector will run without sql counters"
			}

			#for each instance, get process (incuding agent) and mssql specific scounters
			$TargetSqlServers.GetEnumerator() | %{
				$SqlServer = $_.value;
				
				
				if(!$SqlServer.SqlServer){
					return;
				}
				
				$InstanceName  = $_.value.SqlServer.Name;
				log "Building counter list for instance $InstanceName";
				
				
				if($SqlServer.AgentService){
					log "	Loading process counters for sql agent..."
					$ProcCounters = GetProcessCounters -Id ($SqlServer.AgentService.ProcessId);
					log "		counter instance is: $($ProcCounters.CounterInstanceName)"
					$SqlServer.counters.agent += $ProcCounters.CounterList;
					

					$SqlServer.counters.agenthistory += $ProcCounters.CounterListHistory;
				}
				
				log "	Loading process counters for sql server..."
				$ProcCounters = GetProcessCounters -Id ($SqlServer.SqlServer.ProcessId);
				log "		counter instance is: $($ProcCounters.CounterInstanceName)"
				
				$SqlServer.counters.sql +=  $ProcCounters.CounterList;
				$SqlServer.counters.sqlhistory += $ProcCounters.CounterListHistory;
				
				if($InstanceName -eq 'MSSQLSERVER'){
					$InstanceName = 'SQLServer'
				}
				

				$SqlServer.counters.sql += @(
					"\$($InstanceName):Access Methods(*)\*"
					"\$($InstanceName):Buffer Manager(*)\*"
					"\$($InstanceName):Buffer Node(*)\*"
					"\$($InstanceName):Catalog Metadata(*)\*"
					"\$($InstanceName):Databases(*)\*"
					"\$($InstanceName):Exec Statistics(*)\*"
					"\$($InstanceName):General Statistics(*)\*"
					"\$($InstanceName):Latches(*)\*"
					"\$($InstanceName):Locks(*)\*"
					"\$($InstanceName):Memory Manager(*)\*"
					"\$($InstanceName):Memory Node(*)\*"
					"\$($InstanceName):Plan Cache(*)\*"
					"\$($InstanceName):Resource Pool Stats(*)\*"            
					"\$($InstanceName):SQL Statistics(*)\*"
					"\$($InstanceName):Transactions(*)\*"
					"\$($InstanceName):Wait Statistics(*)\*"
					"\$($InstanceName):Workload Group Stats(*)\*"
					"\$($InstanceName):SQL Errors(*)\*"
				)
				
				$DatabaseCounterInstance = '_Total';
				$DatabaseHistoryCounters = @(
						"\$($InstanceName):Databases(*)\Transactions/sec"
						"\$($InstanceName):Databases(*)\Log Bytes Flushed/sec"
				)
				
				if($HistoryDatabaseFull){
					log "WARNING: Using FULL DATABASE COUNTER HISTORY. This can require more space for history...";
					$DatabaseCounterInstance = '*';
				}
				
				$DatabaseHistoryCounters += @(
					"\$($InstanceName):Databases($DatabaseCounterInstance)\Active Transactions"
					"\$($InstanceName):Databases($DatabaseCounterInstance)\Data File(s) Size (KB)"
					"\$($InstanceName):Databases($DatabaseCounterInstance)\Log File(s) Size (KB)"
					"\$($InstanceName):Databases($DatabaseCounterInstance)\Log File(s) Used Size (KB)"
					"\$($InstanceName):Databases($DatabaseCounterInstance)\Log Flush Wait Time"
					"\$($InstanceName):Databases($DatabaseCounterInstance)\Log Growths"
					"\$($InstanceName):Databases($DatabaseCounterInstance)\Write Transactions/sec"

				)
				
				$SqlServer.counters.sqlHistory += $DatabaseHistoryCounters;
				$SqlServer.counters.sqlHistory += @(
					"\$($InstanceName):Buffer Manager(*)\Database Pages"
					"\$($InstanceName):Buffer Manager(*)\Buffer cache hit ratio"
					"\$($InstanceName):Buffer Manager(*)\Free list stalls/sec"
					"\$($InstanceName):Buffer Manager(*)\Page life expectancy"
					"\$($InstanceName):Buffer Manager(*)\Page lookups/sec"
					"\$($InstanceName):Buffer Manager(*)\Page reads/sec"
					"\$($InstanceName):Buffer Manager(*)\Page writes/sec"
					"\$($InstanceName):Buffer Manager(*)\Target Pages"
					"\$($InstanceName):Buffer Node(*)\Page life expectancy"
					"\$($InstanceName):General Statistics(*)\Active Temp Tables"
					"\$($InstanceName):General Statistics(*)\Logical Connections"
					"\$($InstanceName):General Statistics(*)\Logins/sec"
					"\$($InstanceName):General Statistics(*)\Process blocked"
					"\$($InstanceName):General Statistics(*)\Temp Tables Creation Rate"
					"\$($InstanceName):General Statistics(*)\Transactions"
					"\$($InstanceName):General Statistics(*)\User Connections"
					"\$($InstanceName):Latches(*)\Average Latch Wait Time (ms)"
					"\$($InstanceName):Latches(*)\Latch Waits/sec"
					"\$($InstanceName):Locks(_Total)\Average Wait Time (ms)"
					"\$($InstanceName):Locks(_Total)\Lock Wait Time (ms)"
					"\$($InstanceName):Locks(_Total)\Lock Timeouts/sec"
					"\$($InstanceName):Locks(_Total)\Lock Waits/sec"
					"\$($InstanceName):Memory Manager(*)\Free Memory (KB)"
					"\$($InstanceName):Memory Manager(*)\Database Cache Memory (KB)"
					"\$($InstanceName):Memory Manager(*)\SQL Cache Memory (KB)"
					"\$($InstanceName):Memory Manager(*)\Optimizer Memory (KB)"
					"\$($InstanceName):Memory Manager(*)\Total Server Memory (KB)"
					"\$($InstanceName):Memory Manager(*)\Stolen Server Memory (KB)"
					"\$($InstanceName):Memory Node(*)\Free Node Memory (KB)"
					"\$($InstanceName):Plan Cache(_Total)\Cache Pages"        
					"\$($InstanceName):Plan Cache(_Total)\Cache Hit Ratio"        
					"\$($InstanceName):SQL Statistics(*)\Batch Requests/sec"
					"\$($InstanceName):SQL Statistics(*)\SQL Compilations/sec"
					"\$($InstanceName):SQL Statistics(*)\SQL Re-Compilations/sec"
					"\$($InstanceName):Transactions(*)\Free Space in tempdb (KB)"
					"\$($InstanceName):Transactions(*)\Longest Transaction Running Time"
					"\$($InstanceName):Transactions(*)\Transactions"
					"\$($InstanceName):Transactions(*)\Version Store Size (KB)"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Wait for the worker"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Lock waits"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Memory grant queue waits"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Network IO waits"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Page IO latch waits"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Page latch waits"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Log write waits"
					"\$($InstanceName):Wait Statistics(Average wait time (ms))\Log buffer waits"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Wait for the worker"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Lock waits"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Memory grant queue waits"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Network IO waits"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Page IO latch waits"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Page latch waits"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Log write waits"
					"\$($InstanceName):Wait Statistics(Waits in progress)\Log buffer waits"
					"\$($InstanceName):SQL Errors(*)\*"
				)
				
				if($IncludeAdditionalCounters){
					$SqlServer.counters.sql += @(
						"\$($InstanceName):Backup Device(*)\*"
						"\$($InstanceName):Batch Resp Statistics(*)\*"
						"\$($InstanceName):CLR(*)\*"
						"\$($InstanceName):Cursor Manager by Type(*)\*"
						"\$($InstanceName):Cursor Manager Total(*)\*"
						"\$($InstanceName):Deprecated Features(*)\*"
						"\$($InstanceName):FileTable(*)\*"
						"\$($InstanceName):HTTP Storage(*)\*"
						"\$($InstanceName):Memory Broker Clerks(*)\*"            
					)
				}
				
				if($IncludeBrokerCounters){
					$SqlServer.counters.sql += @(
						"\$($InstanceName):Broker Activation(*)\*"
						"\$($InstanceName):Broker Statistics(*)\*"
						"\$($InstanceName):Broker TO Statistics(*)\*"
						"\$($InstanceName):Broker/DBM Transport(*)\*"            
					)
				}
				
				if($IncludeReplicationCounters){
					$SqlServer.counters.sql += @(
						"\$($InstanceName):Replication Agents(*)\*"
						"\$($InstanceName):Replication Snapshot(*)\*"
						"\$($InstanceName):Replication Logreader(*)\*"
						"\$($InstanceName):Replication Dist.(*)\*"
						"\$($InstanceName):Replication Merge(*)\*"            
					)
				}
				
				if($IncludeHadrCounters){
						$SqlServer.counters.sql += @(
							"\$($InstanceName):Availability Replica(*)\*"
							"\$($InstanceName):Database Mirroring(*)\*"
							"\$($InstanceName):Database Replica(*)\*"
							"\$($InstanceName):HADR Availability Replica(*)\*"
							"\$($InstanceName):HADR Database Replica(*)\*"            
						)
				}
			}
		
		
		}
		
		
		function UpdateProcessCounters {
			$CounterListEx.processes = @();
			foreach($Proc in $TargetProcesses){
				log "Adding process $($Proc.Id) ($($Proc.name)) to monitored process list"
				$ProcCounters = GetProcessCounters -Id $Proc.Id;
				log  "	Instance name is: $($ProcCounters.CounterInstanceName)"
				$CounterListEx.processes += $ProcCounters.CounterList;
				$CounterListEx.processHistory += $ProcCounters.CounterListHistory;
			}
		}
	
		
		#This function will compile all counters list on string array with all counters that we must collect.
		function GenerateCounterList {
			param([switch]$HistoryOnly)
		
			[string[]]$CounterList = @();
			
			
			foreach($List in $CounterListEx.GetEnumerator()){
				$ListName 	= $List.key;
				$Counters	= $List.value;
				
				log -v "Checking List $ListName"
				
				if($ListName -eq 'instances'){
					$Counters.GetEnumerator() | %{
						if($HistoryOnly){
							$CounterList += $_.value.agenthistory;
							$CounterList += $_.value.sqlhistory;
						} else {
							$CounterList += $_.value.agent;
							$CounterList += $_.value.sql;
						}
					}
				} else {
					if($HistoryOnly -and $ListName -Notlike '*History'){
							log -v "	Excluding $ListName from counter generation list (history mode off).."
							continue;
					}
					
					if(!$HistoryOnly -and $ListName -like '*History'){
							log -v "	Excluding $ListName from counter generation list (history mode on).."
							continue;
					}
					
					log -v "	Adding $($Counters.count) counters(s)...";
					$CounterList += $Counters
				}
			}
			
			if(Test-Path $PerfCustomCounters){
				log -v "Loading custom counters from $PerfCustomCounters";
				$CounterList += Get-Content $PerfCustomCounters | ? { $CounterList -NotContains $_ };
			}
			
			
			if($HistoryOnly -and (Test-Path $PerfCustomCountersHistory)){
				log -v "Loading custom history counters from $PerfCustomCountersHistory";
				$CounterList += Get-Content $PerfCustomCountersHistory | ? { $CounterList -NotContains $_ };
			}
			
			return @($CounterList | ? {$_});
		}
	
		#(re)Create performance counter collector set.
		#Create Pla.DataCollectorSet com objecft. this will be used to manage data collector...
		#	Refs:https://docs.microsoft.com/en-us/windows/win32/api/pla/nf-pla-idatacollectorset-query
		function CreatePerfCounterCollector {
			param($Settings)
			
			$PerfCounterDS = $DATACOLLECTORS.PerfCounter;
			
			if(!$PerfCounterDS){
				$PerfCounterDS = New-Object -ComObject pla.datacollectorset
				$DATACOLLECTORS.PerfCounter = $PerfCounterDS;
			}

			$CollectorExists = RunCom -IgnoreHResult 0x80300002 {
					$PerfCounterDS.Query($DataCollectorName,$null);
					log -v " Query not throwed error... Collector already exists..."
					return $true;
					
				}
				
			if($CollectorExists){
				$CollectorStatus = $PerfCounterDS.status;
				
				#Possible status: https://docs.microsoft.com/en-us/windows/win32/api/pla/ne-pla-datacollectorsetstatus
				if($CollectorStatus -eq 1){#Running?
					#stop it...
					log "Stopping running collector...";
					$PerfCounterDS.stop($true);
				}
				
				#Removing...
				log "Deleting existing data collector...";
				
				$PerfCounterDS.delete();
				log  "	Success";
			}
			
			#Preparing the parameters to input in logman...
			
				#For security reasons (to prevent full log, if powershhell stops)
				#We will limit data collecto to run up to this time...
				#Powershell loop bellow will keep logman restarted and collecting, renwing this time...
				#this point is essentia because it have logic to prevent logman fill disk above the limit MaxSize...
				#If powershel stops for any reason, this limit ensures that logman will not run indefinedly...
				$MaxRunTimeString = [timespan]::FromSeconds($RenewFrequencySeconds*2).toString();
				log -v "	Data collector -rf (max runtime) will be $MaxRunTimeString";
				
				$Settings.MaxRunTimeString = $MaxRunTimeString;

				$NewfileName = "$CountersLogDirectory\PerfCounters.blg";


				# for data collector works auto create new file after size, we must use bin file , cnf 0 and specify max.
				$MaxSizeMB = $PerCounterFileMaxSize/1024/1024
				$PerfCounterCollectInterval = 1; #Every 1 second.
				$LogManParameters = @(
					"create","counter",$DataCollectorName
					"-f",'bin'
					'-si',$PerfCounterCollectInterval
					'-max',$MaxSizeMB
					'-cf',$PerfCountersFile
					'-cnf',0
					'-ow'
					'-rf',$MaxRunTimeString
					'-o',$NewfileName
				)
				
				$Settings.LogManParameters = $LogManParameters;
			
			log "Creating data collector via logman...";
			log "Parameters: $(@($LogManParameters -Join ' '))"
			$LogManOutput = pslogman @LogManParameters
			log "	Created..."
			
			
			#Getting again...
			log -v "Quering updated data collector.";
			$PerfCounterDS.Query($DataCollectorName,$null);
			log "	Success!"
			
		}

		#Create a trace data collelctor...
		function CreatePerfCounterCollector2 {
			param(
				$Settings
				,$Name
				,$RootPath
				,$MaxDuration
				,$MaxFileSize
				,$SampleInterval = 1
				,$CounterList
				,$CollectorSlot
				,$CollectorName = 'PerfCounter'
			)
			
			$Ds = $DATACOLLECTORS[$CollectorSlot];
			
			if(!$EtwDs){
				$Ds = New-Object -ComObject pla.datacollectorset
				$DATACOLLECTORS[$CollectorSlot] = $Ds;
				$Settings.PerfCounterDs = $Ds;
			}
			
			#This will turn into parameters in some momement ....
			$DsName 					= $Name;
			$OverallDuration 			= $MaxDuration;
			$MaxSizeMB 					= $MaxFileSize/1024/1024
			

			$Ds.RootPath				= $RootPath
			$Ds.Duration				= $OverallDuration  # -rf
			$Ds.Segment             	= $True				# -cnf 0 (on max, create new)
			$Ds.SegmentMaxSize      	= $MaxSizeMB 		# --max


			#Create a new data collector if typpe Etw Trace...
			#https://docs.microsoft.com/en-us/windows/win32/api/pla/nf-pla-idatacollectorcollection-createdatacollector
			$PerfCollector = $Ds.DataCollectors.CreateDataCollector(0); # type = 1
			$Settings.PerfDataCollector = $PerfCollector;
			$PerfCollector.Name = $CollectorName;
			
			#$EtwCollector.FlushTimer 		= 0 By default flushs when buffer fulll
			$PerfCollector.LogOverwrite		= $true;		# -ow
			$PerfCollector.filename			= $CollectorName
			$PerfCollector.FileNameFormat			= 1 			# nnnnn
			$PerfCollector.FileNameFormatPattern	= '\_yyyyMMdd\_HHmmss\_NNNNN' # nnnnn

			#properties from PERF COUNTERS
			#Docs from pla: https://docs.microsoft.com/en-us/windows/win32/api/pla/nn-pla-iperformancecounterdatacollector
			

			$PerfCollector.SampleInterval 		= $SampleInterval
			$PerfCollector.Performancecounters 	= $CounterList; #This is oficial name for Windows Kernel Session that outputs lot of events...
			#$PerfCollector.SegmentMaxRecords = ?

			$Ds.DataCollectors.Add($PerfCollector);
			
			log -v "(re)creating the performance log (Name: $DsName)";
			$Results = $Ds.Commit($DsName,$null,0);
			log -v "	Sucess!";
		}


		#Setup data collector set for performance counters.
		function SetupPerfCounterCollector {
			param($Config,$Settings,$FirstTime)

			log "Generating counters list...";
			[string[]]$CountersList = GenerateCounterList;
			log "	Total counters: $($CountersList.count)";
			$CountersList | %{
				log -v "	Counter: $_";
			}
			
			log "Writing config file $PerfCountersFile"
			$CountersList | Out-File $PerfCountersFile -Encoding ASCII
			
			$Settings.CounterList = $CountersList;
			
			log "Generating updating process counter mapping";
			$Settings.CounterListHistory = $CountersList;
			
			log "Generating updating process counter mapping";
			$CounterMapping = GetProcessCounterMapping;
			$SETTINGS.CounterMapping = $CounterMapping;
			
			$MappingFileFullPath = GetCurrentFile -Directory $CountersLogDirectory -Filter 'CounterMapping_*.txt' -MaxSize 20MB;
			
			$CurrentContent = Get-Content $MappingFileFullPath -EA SilentlyContinue;
			
			log "Exporting mapping of counters to $MappingFileFullPath"
			@(
				"--------------------------------------"
				"MAPPING DATE: $(Get-Date)"
				""
				($SETTINGS.CounterMapping|ft -AutoSize -Wrap|Out-String)
				$CurrentContent
			)  | Out-file -Force $MappingFileFullPath;
			
			log "Creating perfcounter data collector...";
			$CounterParams = @{
				Settings		= $Settings
				RootPath 		= $CountersLogDirectory
				MaxDuration		= $RenewFrequencySeconds
				MaxFileSize		= $PerCounterFileMaxSize
				Name			= $DataCollectorName
				SampleInterval 	= 1
				CounterList		= $CountersList
				CollectorSlot	= "PerfCounter"
			}
			
			CreatePerfCounterCollector2 @CounterParams
		}
		
		function SetupCountersHistoryCollector {
			param($Config,$Settings,$FirstTime,$Prexec)
			
			
			$CollectDirectory 			= $Config.Path
			$PerfCountersFileHistory 	= "$CollectDirectory\PerfmonCountersHistory.config"

			log "Generating history counters list...";
			[string[]]$CountersList = GenerateCounterList -HistoryOnly;
			log "	Total counters: $($CountersList.count)";
			$CountersList | %{
				log -v "	Counter: $_";
			}
			
			log "Writing config file $PerfCountersFileHistory"
			$CountersList | Out-File $PerfCountersFileHistory -Encoding ASCII
			log "	done!";
			
			
			$Settings.CounterListHistory = $CountersList;
			
			log "Generating updating process counter mapping";
			$CounterMapping = GetProcessCounterMapping;
			$SETTINGS.CounterMappingHistory = $CounterMapping;
			
			$MappingFileFullPath = GetCurrentFile -Directory $CollectDirectory -Filter 'CounterMapping_*.txt' -MaxSize 20MB;
			
			$CurrentContent = Get-Content $MappingFileFullPath -EA SilentlyContinue;
			
			log "Exporting mapping of counters to $MappingFileFullPath"
			@(
				"--------------------------------------"
				"MAPPING DATE: $(Get-Date)"
				""
				($SETTINGS.CounterMappingHistory|ft -AutoSize -Wrap|Out-String)
				$CurrentContent
			)  | Out-file -Force $MappingFileFullPath;
		
			log "Creating perfcounter data collector...";
			$CounterParams = @{
				Settings		= $Settings
				RootPath 		= $CollectDirectory
				MaxDuration		= $Config.RenewConfig.Frequency
				MaxFileSize		= $Config.MaxPerfCounterSize
				Name			= ($DataCollectorName+"_history")
				SampleInterval 	= $Config.SampleInterval
				CounterList		= $CountersList
				CollectorSlot	= "PerfCounterHistory"
				CollectorName	= 'PerfHistory'
			}
			
			CreatePerfCounterCollector2 @CounterParams;
		}
		
		#Renew function.
		function CountersRenew {
			log -v "Renewing PerfCounter collector";
			StopDataCollectorSet "PerfCounter";
			StartDataCollectorSet "PerfCounter";
			log -v "	Renew Done!";
		}
		
		function CountersHistoryRenew {
			log -v "Renewing PerfCounterHistory collector";
			StopDataCollectorSet "PerfCounterHistory";
			StartDataCollectorSet "PerfCounterHistory";
			log -v "	Renew Done!";
		}
	
	### FUNCTIONS IMPLEMENT KERNEL event trace COLLECTOR
	
		#Get elegible flags...
		function GetElegibleFlags {
			param(
				$UserChoices = @()
			)
		
			$SystemProviderFlags = @{
				alpc 				= 0x00100000
				cswitch 			= 0x00000010
				disk_file_io		= 0x00000200
				disk_io				= 0x00000100
				disk_io_init		= 0x00000400
				dispatcher			= 0x00000800
				dpc					= 0x00000020
				driver				= 0x00800000
				file_io				= 0x02000000
				file_io_init		= 0x04000000
				image_load			= 0x00000004
				interrupt			= 0x00000040
				job					= 0x00080000
				hard_faults			= 0x00002000
				page_faults			= 0x00001000
				tcpip				= 0x00010000
				no_sysconfig		= 0x10000000
				process				= 0x00000001
				process_counters 	= 0x00000008
				profile 			= 0x01000000
				registry 			= 0x00020000
				split_io		 	= 0x00200000
				syscall 			= 0x00000080
				thread 				= 0x00000002
				vamap 				= 0x00008000
				virtual_alloc 		= 0x00004000
			}
			
			$result = @();
			
			@($KernelFlags) + @($KernelAdditionalFlags) | sort -Unique | %{
				$FlagValue = $SystemProviderFlags[$_];
				
				if($FlagValue -eq $null){
					log "KernelLog setup: Flag not found: $_";
					return;
				}
				
				$Output += $FlagValue;
			}
			
			return $result;
		}
	
		#Create a trace data collelctor...
		function CreateKernelLogCollector {
			param($Settings)
			
			$EtwDs = $DATACOLLECTORS.kernel;
			
			if(!$EtwDs){
				$EtwDs = New-Object -ComObject pla.datacollectorset
				$DATACOLLECTORS.kernel = $EtwDs;
				$Settings.DataCollectorSet = $EtwDs;
			}
			
			#This will turn into parameters in some momement ....
			$DsName 					= $DataCollectorName+"_kernelog";
			$OverallDuration 			= $KernelRenewSeconds;
			
			if(!$KernelLoggerFileMaxSize){
				$KernelLoggerFileMaxSize = 100MB;
			}
			
			$MaxSizeMB = $KernelLoggerFileMaxSize/1024/1024
			
			$LogManParameters = @(
				"create","counter",$DataCollectorName
				"-f",'bin'
				'-si',$PerfCounterCollectInterval
				'-cf',$PerfCountersFile
				'-cnf',0
				'-o',$NewfileName
			)
		
			$EtwDs.RootPath				= $KernelLogDirectory
			$EtwDs.Duration				= $OverallDuration  # -rf
			$EtwDs.Segment             	= $True				# -cnf 0 (on max, create new)
			$EtwDs.SegmentMaxSize      	= $MaxSizeMB 		# --max


			#Create a new data collector if typpe Etw Trace...
			#https://docs.microsoft.com/en-us/windows/win32/api/pla/nf-pla-idatacollectorcollection-createdatacollector
			$EtwCollector = $EtwDs.DataCollectors.CreateDataCollector(1); # type = 1
			$Settings.DataCollector = $EtwCollector;
			$EtwCollector.Name = 'KernelLog';
			
			
			#$EtwCollector.FlushTimer 		= 0 By default flushs when buffer fulll
			$EtwCollector.LogOverwrite		= $true;		# -ow
			$EtwCollector.filename			= 'kernel'
			$EtwCollector.FileNameFormat			= 1 			# nnnnn
			$EtwCollector.FileNameFormatPattern	= '\_yyyyMMdd\_HHmmss\_NNNNN' # nnnnn

			#Event traces properties from ETW EVENT_TRACE_PROPERTIES:https://docs.microsoft.com/en-us/windows/win32/api/evntrace/ns-evntrace-event_trace_properties
			#Docs from pla: https://docs.microsoft.com/en-us/windows/win32/api/pla/nn-pla-itracedatacollector
			$EtwCollector.BufferSize 		= $KernelLogBufferSize
			#$EtwCollector.MaximumBuffers 	= 128 ETW calculat ethis based on RAM
			#$EtwCollector.PreAllocatefile 	= $true
			$EtwCollector.SessionName 		= "NT Kernel Logger"; #This is oficial name for Windows Kernel Session that outputs lot of events...


			#https://docs.microsoft.com/en-us/windows/win32/api/pla/ne-pla-streammode
			#$EtwCollector.StreamMode = 1 #file

			#This is the list of flags that user can enable and serve as list of  events that can be output from kernel...
			$SystemProviderFlags = @{
				alpc 				= 0x00100000
				cswitch 			= 0x00000010
				disk_file_io		= 0x00000200
				disk_io				= 0x00000100
				disk_io_init		= 0x00000400
				dispatcher			= 0x00000800
				dpc					= 0x00000020
				driver				= 0x00800000
				file_io				= 0x02000000
				file_io_init		= 0x04000000
				image_load			= 0x00000004
				interrupt			= 0x00000040
				job					= 0x00080000
				hard_faults			= 0x00002000
				page_faults			= 0x00001000
				tcpip				= 0x00010000
				no_sysconfig		= 0x10000000
				process				= 0x00000001
				process_counters 	= 0x00000008
				profile 			= 0x01000000
				registry 			= 0x00020000
				split_io		 	= 0x00200000
				syscall 			= 0x00000080
				thread 				= 0x00000002
				vamap 				= 0x00008000
				virtual_alloc 		= 0x00004000
			}

			#Create the system provider... This guid is fixed...
			#I expect every windows version =)
			$SystemTraceProvider = $EtwCollector.TraceDataProviders.CreateTraceDataProvider();
			$SystemTraceProvider.DisplayName = '{9E814AAD-3204-11D2-9A82-006008A86939}'
			$Settings.TraceProvider = $SystemTraceProvider;

			$TargetFlags = @($KernelFlags) + @($KernelAdditionalFlags);
			
			GetElegibleFlags $TargetFlags | %{
				$SystemTraceProvider.KeywordsAny.Add($_);
			}

			$EtwCollector.TraceDataProviders.Add($SystemTraceProvider);
			$EtwDs.DataCollectors.Add($EtwCollector);
			
			log -v "(re)creating the kernel log (Name: $DsName)";
			$Results = $EtwDs.Commit($DsName,$null,0);
			log -v "	Sucess!";
		}

		function SetupKernelLogCollector {
			param($Config,$Settings,$FirstTime)
				
			if($FirstTime){
				#Just need create first time... Nothing change after here...
				log "Creating kernel log collector..."
				CreateKernelLogCollector $Settings
			}
		}

		function KernelRenew {
			log -v "Renewing Kernel collector";
			StopDataCollectorSet "Kernel";
			StartDataCollectorSet  "Kernel"
			log -v "	Renew Done!";
		}
	

	### Fuunctions implement xperf COLLECTOR
		
		function XPerfSetup {
			param($Config,$SettingsLog,$FirstTime)
			
			#Xperf is installed?
			$CommandInfo = Get-Command xperf -EA SilentlyContinue
			
			if(!$CommandInfo){
				throw "xperf.exe not found. Correclty installed? On path environemtn?";
			}
			
			#Build flags..
			$Config.RuntimeData.xperfparams = @{
				stackwalk 	= $XPerfStackWalk -Join "+"
				on			= $XPerfFlags -Join "+"
			}
			
			#Create the running directory...
			$RunningDir 	= $Config.Path+"\running";
			$MergingDir 	= $Config.Path+"\merging";
			$d = mkdir -force $RunningDir;
			$d = mkdir -force $MergingDir;
		}
		
		
		#Collect using xperf...
		function InvokeXPerf {
			$OriginalEA = $ErrorActionPreference;
			$ErrorActionPreference = "SilentlyContinue";
			$Output = xperf @Args 2>&1;
			$ExitCode = $LASTEXITCODE;
			$ErrorActionPreference = $OriginalEA;
			
			if($ExitCode){
				throw "xperf error! ExitCode: $ExitCode | Output: $Output"
			}
			
			return $Output;
		}
		
		#Start powershell job to collect process...
		function StartXPerfJob {
			param($CollectName, $Config)
			
			$JobData = @{
				CollectorName	= $CollectName
				Config 			= $Config
			}
			
			StartJob XPerfJob {
					param($Data)
			
					$SleepTime = $Data.Config.RenewConfig.Frequency/2;
					$JobMaxRuntime = $Data.Config.JobMaxRuntimeSeconds
					$CollectorName = $Data.CollectorName
					
					if($SleepTime -lt 1){
						$SleepTime = 1;
					}
					
					$StartRun = (Get-date);
					
					
					log "Starting xperf collect job. MaxRunTime is $JobMaxRuntime secs"
					
					while($true){
						DoXPerfCollect $CollectorName $Config
						
						CheckVerboseEnabled
						
						log -v "Starting process collect sleep by $SleepTime secs"
						start-sleep -s $SleepTime;
						
						$Elapsed = (Get-Date) - $StartRun;
						
						if($Elapsed.totalSeconds -ge $JobMaxRuntime){
							log "Job ending due to MaxRunTime!";
							break;
						}
					}
					
					return "NORMAL_END:MAXRUNTIME";
				}  -Force -Data $JobData
		}
		
		
		function DoXPerfCollect {
			param($Name,$Config)
			
			$LogDir 		= $Config.Path;
			$RunningDir		= "$Logdir\running";
			$MergingDir		= "$Logdir\merging";
			

			log -v "Stopping current...";
			$out = InvokeXPerf -loggers "NT Kernel Logger";
			
			
			if($out -ne "No Selected Active Loggers"){
				$Output = InvokeXPerf -stop;
			}
			
			log -v "Merging pending files...";
			gci $RunningDir\*.etl | %{
				$MergedName = $_.Name.replace('.etl','_merged.etl');
				$FullPath = "$LogDir\$MergedName";
				log -v "Mergin $_ to $FullPath";
				$MergeOutput = InvokeXPerf -merge $_.FullName $FullPath;
				
				#Remove original...
				log -v "Removing $_..."
				$_ | Remove-Item -force;
			}
			
		
			$Params = $Config.RuntimeData.xperfparams;
			
			
			$ts			= (Get-Date).toString("yyyyMMdd_HHmmssfff");
			$LogName	= "$LogDir\running\xperf_$($ts).etl"
			$MaxSizeMB 	= ($KernelLoggerFileMaxSize/1024/1024)*4
			
			$XPerfStartParams = @(
				"-on",$Params.on
				"-stackwalk",$Params.stackwalk
				"-f",$LogName
				"-MaxFile",$MaxSizeMB
			)
			
			if($KernelLogBufferSize){
				$XPerfStartParams += "-BufferSize",$KernelLogBufferSize
			}
			
			log -v "Starting xperf again...Parameters: $XPerfStartParams";
			$StartOutput = InvokeXPerf @XPerfStartParams
		}


		function XPerfRenew {
			param($Name,$Config)

			log -v "Renewing xperf collector";
			
			if(!$Config.IsAsync){
				log -v "Calling xperf synchronous...";
				DoXPerfCollect $Name $Config;
				return;
			}
			
			
			$CurrentJob = $Config.RuntimeData.Job;
			
			if(!$CurrentJob){
				log -v "Starting xperf job...";
				$CurrentJob = StartXPerfJob $Name $Config
				$Config.RuntimeData.Job  = $CurrentJob;
				log -v "	Xperf Job started successfully..."
			}
			
			if($CurrentJob.state -eq "Failed"){
				log "Xperf job appears failed... Check next log messages";
				$output = $CurrentJob | rcjb
				log "Xperf job output: $output";
				$removed = $CurrentJob | rjb;
				
				throw "FAILED_XPERFJOB: $output";
			}
				
			if($CurrentJob.State -eq "completed"){
				log -v "Xperf job appears completed";
				$output = $CurrentJob | rcjb
				
				if($output -eq "NORMAL_END:MAXRUNTIME"){
						log -v "Completed due to expired runtime. This is normal... Restarting job...";
						$CurrentJob = StartXPerfJob $Name $Config
						$Config.RuntimeData.Job  = $CurrentJob;
						log -v "	Success...";
				} else {
					throw "UNEXPECTED_XPERFCOLLECT_OUTUT: $output";
				}
			}
			
			
			
			log -v "	Renew of xperf done!"
		}
		
	### FUNCTIONS IMPLEMENT SQL COLLECT
		
	
		#takes a sql or file, and a instance name and runs a sql on it
		#returns the resultsets and/or errors .
		function RunSqlScript {
			param($ServerInstance,$File,$SQL,$User,$Password,$Database = 'master')
					
			if($User){
				$AuthString = "User=$User;Password=$Password";
			} else {
				$AuthString = "Integrated Security=True";
			}
			
			$ConnectionStringParts = @(
				"Server=$ServerInstance"
				"Database=$Database"
				$AuthString
				"APP=SQLPerfCollect"
			)

			$NewConex = New-Object System.Data.SqlClient.SqlConnection
			$NewConex.ConnectionString = $ConnectionStringParts -Join ";"
			$DataSet = New-Object System.Data.DataSet;
			
			if($File){
				$SQL = Get-Content $File -Encoding UTF8;
			}
			

			log -v "Opening SQL connection..."
			try {
				$NewConex.Open()
				$commandTSQL = $NewConex.CreateCommand()
				$commandTSQL.CommandTimeout = 0;
				$ReaderWrapper = @{reader=$null}
				$commandTSQL.CommandText = $SQL;
				log -v "Running SQL command";
				$ReaderWrapper.reader = $commandTSQL.ExecuteReader();
				
				while(!$ReaderWrapper.reader.IsClosed){
					$DataSet.Tables.Add().Load($ReaderWrapper.reader);
				}
				
			} finally {
				$NewConex.Dispose();
			}
				
			return @($DataSet.Tables);	
		}
		
		#Do the main work: determine what SQl execute and the instances.
		#Then, calls RunsSqlScript to run it.
		function InvokeSqlCollect {
			param($Config,$FilterInstanceName = @(),$MaxRuntime = $null,$FrequencySeconds)

			$SqlDirectory 	= $Config.SqlPath;
			$DirPath 		= $Config.Path
			$Sqlcommands	= $config.SqlCommands;
			$SourceSQL		= @()
			$OutputType		= $Config.OutputType
			
			if(!$TargetSqlServers){
				log -v "No SQL instances to work on";
				return;
			}
			
			if(Test-Path $SqlDirectory){
				log -v "Getting all sql files to run from $SqlDirectory";
				$AllSQLFiles = gci $SqlDirectory\*.sql;
				
			
				if($AllSQLFiles){
					$AllSQLFiles | %{
						$SourceSQL += New-Object PsObject -Prop @{
									SourceName 		= $_.Name
									SourceType		= "File"
									SourceContent	= $_;
									SourceOutputType	= $OutputType;
								}
					}
				}
			
			}
			


			if($Sqlcommands){
				foreach($Sql in $Sqlcommands.GetEnumerator()){
					
					$SqlSourceInfo = $Sql.value;
					$Content = $SqlSourceInfo.sql;
					
					$OutType = $SqlSourceInfo.type
					
					if(!$OutType){
						$OutType = $OutputType
					}
					
					$SourceSQL += New-Object PsObject -Prop @{
								SourceName 		= $Sql.key
								SourceType		= "SQL"
								SourceContent	= $Content;
								SourceOutputType = $OutType
							}
				}
			}
			
			if($FilterInstanceName){
				$ElegibleInstances 	= $TargetSqlServers[$FilterInstanceName]
			} else {
				$ElegibleInstances 	= $TargetSqlServers.values; 
			}
			

			log "Running files on instances..."
			$StartTime = (Get-Date);
			while($true){
				foreach($Sql in $ElegibleInstances){
					
					$ServerName = $Sql.ServerAddress;
					$InstanceName = $sql.InstanceName;
					
					$DirOutput = "$DirPath\$InstanceName";
					if(-not(Test-Path $DirOutput)){
						$nd = mkdir $DirOutput;
					}

					
					#TODO: Try connect and do a simple select 1... If not workings remove from list...
					foreach($Source in $SourceSQL){
					
						

						$Result = @{
							result 	= $null
							error	= $null	
						}
					
						$RunSqlParams = @{
								ServerInstance 	= $ServerName
							}
						
						$RunSqlParams[$Source.SourceType] = $Source.SourceContent;

						
						log -v "Running $($Source.SourceName) (Type: $($Source.Sourcetype)) on instance $ServerName";
						try {	
							$Result.result = RunSqlScript @RunSqlParams;
						} catch {
							$Result.error = $_
						}

						$OutputType = $Source.SourceOutputType;
						$FileName = $Source.SourceName+"_*."+$OutputType;
						$CurrentFile = GetCurrentFile -dir $DirOutput -filter $FileName -MaxSize $SqlLogMaxSize;
						
						log -v "Exporting to $CurrentFile...";
						
						switch($OutputType){
							"csv" {

						
							
								if($Result.error){
									$FileNameError = $Source.SourceName+"_error_*.txt";
									$CurrentFileError = GetCurrentFile -dir $DirOutput -filter $FileNameError -MaxSize $SqlLogMaxSize;
									
									@(
										"Error on collect from $(Get-Date)"
										"$($Result.error)"
										""
									) >> $CurrentFileError
								}
								
								if($Result.result){
									$ts = (Get-date).toSTring("yyyyMMdd HH:mm:ss.fff")
									$TsProp = @{ N = "_Ts"; E={$ts} }
									$Result.result[0] | select $TsProp,* | Export-Csv -Force -Append $CurrentFile
								}
								
								
							}
							
							"xml" {
								try {
									[object[]]$CurrentOutput = Import-CliXml $CurrentFile;
								} catch {
									log -v "Cannot import current output file: $_";
								}
								
								if(!$CurrentOutput){
									[object[]]$CurrentOutput = @()
								}
								
														
								$CurrentOutput += New-Object PsObject -Prop $Result;
								$CurrentOutput | Export-Clixml $CurrentFile;
							}
							
							default {
								throw "INVALID_OUTPUT_TYPE:$OutputType"
							}
						}

						
					}
				}
			
				if($FrequencySeconds){
					log -v "Collect frequency enabled: $FrequencySeconds";
					
					if($MaxRunTime){
						$Elapsed = (Get-Date) - $StartTime;
						if($Elapsed.totalSeconds -gt $MaxRunTime){
							log -v "	Max collect time expired. Will end. Elapsed: $Elapsed";
							break;
						}
					}
					
					CheckVerboseEnabled
					
					log -v "Sleeping to next set of collects...";
					Start-Sleep -s $FrequencySeconds;
				} else {
					break;
				}
				
			}
			
		}
		
		#Start the job for each instance that need sql collector.
		function StartSqlCollectJob {
			param($CollectConfig,$JobConfig)
			
			$JobParams = @{
				Config 			= $CollectConfig
				InstanceInfo	= $JobConfig.Instance
			}
			
			
			StartJob $JobConfig.JobName {
						param($Params)
						
						$SleepTime = $SqlLogSeconds/2;
						
						if($SleepTime -lt 1){
							$SleepTime = 1;
						}
						
						$StartRun = (Get-date);
						
						$InstanceInfo = $Params.InstanceInfo;
						$InstanceName = $InstanceInfo.InstanceName;
						$MaxrunSeconds =  $CollectConfig.JobMaxRuntimeSeconds
						
						log "Starting sql collect of $InstanceName. MaxRunTime is $MaxrunSeconds secs"
						
						
						$Params = @{
							Config 					= $Params.Config
							FilterInstanceName 		= $InstanceName
							FrequencySeconds		= $Params.Config.CollectFrequencySeconds
							MaxRunTime				= $MaxrunSeconds
						}
						
						InvokeSqlCollect @Params;
							
						
						return "NORMAL_END:MAXRUNTIME";
					}  -Force -Data $JobParams
		}
		
		#entry point for SQL Collector.
		#If async, starts jobs.
		#If sync, connects to sql and executes queries.
		function DoSqlCollect {
			param($CollectName,$Config)
			
		
			if(!$SqlLogSeconds){
				log -v "No sql collect due to SqlLogSeconds is 0"
				return;
			}
			
			if(!$Config.IsAsync){
				InvokeSqlCollect $Config;
				return;
			}
			
			$Jobs = $Config.RuntimeData.Jobs 
			if(!$Jobs){
				$Jobs = @{};
				$Config.RuntimeData.Jobs = $Jobs;
			}	
			
			#Build Expected job list...
			$ExpectedJobs = @();
			foreach($Instance in $TargetSqlServers.GetEnumerator()){
				$ExpectedJobs += @{
						JobName 	= "SqlCollect_"+$Instance.key;
						Instance	= $Instance.value
					}
			}
			
			#for each expected jobs...
			$Jobs2Start = @();
			foreach($JobConfig in $ExpectedJobs){
				#Get on job slot..
				$JobName 		= $JobConfig.JobName;
				$InstanceInfo 	= $JobConfig.InstanceInfo;
				
				
				$Job = $Jobs[$JobName]
			
				#Started a process job?
				if(!$Job){
					$Jobs2Start += $JobConfig;
					continue;
				}
				
				if($Job.state -eq "running"){
					log -v "Collect sql job $JobName running. Nothing to do";
					continue;
				}
				
				#Job terminated...
				$Failed = $false;
				try {
					$JobResults = $job | rcjb;
				
					if($Job.State -eq "failed"){
						$Failed = $true;
					}
				} catch {
					log "Job $JobName failed o receive: $_"; 
					$JobResults = $_;
					$Failed = $true;
				}

				if($Failed){
					log "Job $JObName failed. Check previous message or job log. output:`r`n$JobResults";
					continue;
				}
				
				switch($JobResults){
					"NORMAL_END:MAXRUNTIME" {
						log -v "Completed due to expired runtime. This is normal... Restarting job...";
						$Jobs2Start += $JobConfig;
					}
					
					default {
						log "Sql collect job $JobName ended anormally: $JobResults";
					}
				}
			}
			
			#Starting jobs that need restart..
			foreach($JobConfig in $Jobs2Start){
				log -v "Starting SQL Collect job $($JobConfig.JObName)"
				$Jobs[$JobConfig.JobName] = StartSqlCollectJob $Config $JobConfig
				log  -v "	Done!";
			}
			
		}	
		

	## END FUNCTION AREA ##
	write-debug "ATTENTION: DEBUG MODE ENABLED!";
	
	$ScriptName = $MyInvocation.MyCommand.Name;
	$ScriptBound = $PsBoundParameters;
	$ScriptInvocation = $MyInvocation;
	
	log -v "Updating script functions..."
	$ScriptFunctions = gci Function:\ | ?{  -not ($ExistingFunctions -contains $_.name) }
	$AllScriptParameters = GetParameters;


	CheckVerboseEnabled

	#Important variables.
	
	
	$DATACOLLECTORS = @{};
	#Here, will will put content of configuration to be used with logman'
	$CountersList = @()
	$CounterListEx = @{
		SO			= @()
		SOHistory	= @()
		instances	= @{}
		processes	= @()
		processHistory = @()
	}
	#This is list of all monitored process other than sql server instances
	$ExpectedProcessNames = @('rhs')
	$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name;
	
	
	
	#### Validations
	if(!(IsAdmin)){
		throw "Must run as Administrator!";
	}
	
	log "Running as $CurrentUser";
	
	if(!$DataCollectorName){
		$DataCollectorName = $ScriptName.replace('.ps1','')+"_"+$DirectoryItem.Name
	}

	if($ExtraProcessNames){
		$ExpectedProcessNames += $ExtraProcessNames
	}
	
	$ExpectedProcessNames = $ExpectedProcessNames | sort -Unique | ? {  
		if($ExcludeProcessNames -contains $_){
			log " Process $_ excluded due to exclusion list"
		} else {
			return $true;
		}
	};

	# Basic SO Counters
	if(!$NoSOCounters){
		$CounterListEx.SO =  @(
			'\LogicalDisk(*)\*'
			'\Network Interface(*)\*'
			'\Memory(*)\*'
			'\Paging file(*)\*'
			'\PhysicalDisk(*)\*'
			'\Processor Information(*)\*'
			'\System(*)\*'
			'\TCPv6\*'
			'\TCPv4\*'
			'\IPv4\*'
			'\IPv6\*'
			'\UDPv4\*'
			'\UDPv6\*'
			'\TCPIP Performance Diagnostics\*'
			'\TCPIP Performance Diagnostics(Per-CPU)(*)\*'
		)
		
		$CounterListEx.SOHistory =  @(
			'\LogicalDisk(*)\% Idle Time'
			'\LogicalDisk(*)\% Free Space'
			'\LogicalDisk(*)\Avg. Disk Bytes/Transfer'
			'\LogicalDisk(*)\Avg. Disk sec/Read'
			'\LogicalDisk(*)\Avg. Disk sec/Transfer'
			'\LogicalDisk(*)\Avg. Disk sec/Write'
			'\LogicalDisk(*)\Current Disk Queue Length'
			'\LogicalDisk(*)\Avg. Disk Bytes/sec'
			'\LogicalDisk(*)\Disk Bytes/sec'
			'\LogicalDisk(*)\Disk Transfer/sec'
			'\LogicalDisk(*)\Disk Read Bytes/sec'
			'\LogicalDisk(*)\Disk Reads/sec'
			'\LogicalDisk(*)\Disk Write Bytes/sec'
			'\LogicalDisk(*)\Disk Writes/sec'
			'\LogicalDisk(*)\Free Megabytes'
			'\Network Interface(*)\Bytes Received/sec'
			'\Network Interface(*)\Bytes sent/sec'
			'\Network Interface(*)\Bytes Total/sec'
			'\Network Interface(*)\Output Queue Length'
			'\Network Interface(*)\Packets Outbound Discarded'
			'\Network Interface(*)\Packets Outbound Errors'
			'\Network Interface(*)\Packets Received Discarded'
			'\Network Interface(*)\Packets Received Errors'
			'\Network Interface(*)\Packets Received/sec'
			'\Network Interface(*)\Packets Sent/sec'
			'\Network Interface(*)\Packets/sec'
			'\Memory(*)\Pages/sec'
			'\Memory(*)\Pages Input/sec'
			'\Memory(*)\Pages Output/sec'
			'\Memory(*)\Page Reads/sec'
			'\Memory(*)\Page Writes/sec'
			'\Memory(*)\Page Faults/sec'
			'\Memory(*)\Commit Limit'
			'\Memory(*)\Available MBytes'
			'\Memory(*)\% Committed Bytes In Use'
			'\Memory(*)\Cache Bytes'
			'\Memory(*)\Committed Bytes'
			'\Paging file(*)\*'
			'\Processor Information(*)\% DPC Time'
			'\Processor Information(*)\% Interrupt Time'
			'\Processor Information(*)\% Privileged Time'
			'\Processor Information(*)\% Priority Time'
			'\Processor Information(*)\% User Time'
			'\System(*)\Processes'
			'\System(*)\Context Switches/sec'
			'\System(*)\Exceptions Dispatches/sec'
			'\System(*)\PRocessor Queue Length'
			'\System(*)\Threads'
			'\System(*)\System Up Time'
			'\System(*)\File Data Operations/sec'
			'\TCPv6\Connections Active'
			'\TCPv6\Connections Failures'
			'\TCPv4\Connections Active'
			'\TCPv4\Connections Failures'
		) 
	}

	$PerfCustomCounters	= "$DirectoryPath\CustomCounters.config";
	$PerfCustomCountersHistory = "$DirectoryPath\CustomCountersHistory.config";
	$PerfCountersFile 	= "$DirectoryPath\PerfmonCounters.config"
	
	log "Working Directory: $DirectoryPath" 
	log "Data collector name:  $DataCollectorName"
	log "MaxLogsSize: $MaxCollectSize byte(s) | PerCounterFileMaxSize: $PerCounterFileMaxSize byte(s)"
	
	if($MaxCountersCollectSize){
		log "Max Counters log directory size: $MaxCountersCollectSize  byte(s)"
	}
	
	if($MaxProcessCollectSize){
		log "Max Process log directory size: $MaxProcessCollectSize  byte(s)"
	}
	
	log "CheckFrequency: $CheckFrequency"
	log "RenewFrequency: $RenewFrequency"

	
	if($MaxProcessTime){
		$MaxProcessTimeSeconds = Human2Secs $MaxProcessTime;
	} else {
		$MaxProcessTimeSeconds = $MaxCollectTimeSeconds;
	}

	if(!$KernelRenewFrequency){
		throw "EMPTY_KERNEL_RENEW. You must specify a valid value for -KernelRenewFrequency or let default"
	}
	
	
	
	$RenewFrequencySeconds 	= Human2Secs $RenewFrequency
	$CheckFrequencySeconds 	= Human2Secs $CheckFrequency
	$MaxCollectTimeSeconds  = Human2Secs $MaxCollectTime
	$CheckChangesFrequencySeconds  = Human2Secs $CheckChangesFreq
	$ProcessJobMaxRuntimeSeconds = Human2Secs $ProcessJobMaxRuntime
	$KernelRenewSeconds = Human2Secs $KernelRenewFrequency
	$SqlJobMaxRuntimeSeconds = Human2Secs $SqlJobMaxRuntime
	$InternalCollectFrequencySeconds = Human2Secs $InternalCollectFrequency
	$HistoryRenewFrequencySeconds = Human2Secs $HistoryRenewFrequency 
	
	
	if(!$ProcessJobMaxRuntimeSeconds){
		$ProcessJobMaxRuntimeSeconds = $RenewFrequencySeconds;
	}
	
	if(!$SqlJobMaxRuntimeSeconds){
		$SqlJobMaxRuntimeSeconds = $RenewFrequencySeconds
	}
	
	
	if($ProcessLogFrequency){
		log "Process log frequency: $ProcessLogFrequency"
		$ProcessLogSeconds = Human2Secs $ProcessLogFrequency
	}
	
	if($SqlLogFrequency){
		log "Sql log frequency: $SqlLogFrequency"
		$SqlLogSeconds = Human2Secs $SqlLogFrequency
	}
	
	if($MaxKernelCollectSize -eq $null){
		$MaxKernelCollectSize = $MaxCollectSize * 0.1;
	}
	
	if(!$InternalCollectFrequencySeconds){
		$InternalCollectFrequencySeconds  = 300;
	}
	
	if(!$HistoryRenewFrequencySeconds){
		$HistoryRenewFrequencySeconds = $RenewFrequency*2;
	}
	
	log "Max kernel collect size is: $MaxKernelCollectSize";
	log "Internal collect is: $InternalCollectFrequency ($InternalCollectFrequencySeconds)"

	#some legacy code still use this variables. TODO: Migrate all to use config hahstable...
	$CountersLogDirectory 	= "$DirectoryPath\log_perfcounters"
	$ProcessLogDirectory 	= "$DirectoryPath\log_process"
	$SettingsLogDirectory	= "$DirectoryPath\settings"
	$KernelLogDirectory		= "$DirectoryPath\log_kernel"
	$InternalLogDirectory		= "$DirectoryPath\log_internal"
	$CounterMappingFile 	= 'CounterMapping_*.txt'
	$JobsPath				= "$DirectoryPath\psjobs"

	if(-not(Test-Path $SettingsLogDirectory)){
		$nd = mkdir $SettingsLogDirectory;
	}

	if(-not(Test-Path $JobsPath)){
		$nd = mkdir $JobsPath;
	}

	
	$KernelLogEnabled = [bool]$KernelLog;
	
	if($KernelLogEnabled -and $XPerfLog){
		$KernelLogEnabled = $false;
		$XPerfEnabled = $true;
		log "Attention: Kernelog loggin will be made using xperf tool! Kernel Log with data collector set will be disabled!";
	} else {
		$XPerfEnabled = $false;
	}	
	


	$ProgressFile = "$SettingsLogDirectory\progress.xml";


	
	
	try {
	   import-module FailoverClusters;
	   $ContainsFailoverClusterModule = $true;
	   
		$ClusterService = Get-Service clussvc -EA SilentlyContinue;
		
		if(!$ClusterService -or $ClusterService.status -ne 'Running'){
			log -v "Cluster service not running. Ignoring...";
			$ContainsFailoverClusterModule = $false;
		}
	} catch {
		$ContainsFailoverClusterModule = $false;
		log -v "Cannot import failover module cluster: $_";
	}
	
	$INTERNAL_DATA = @{}
			
	$CheckSizeExcludes = @($CounterMappingFile);
			
	#COLLECTS CONFIGURATION 
	$COLLECTS = @{
		internal = @{
				Path 	= $InternalLogDirectory
				Enabled = $true
				RenewConfig  = @{
						Frequency = $InternalCollectFrequencySeconds
						Func = "DoInternalCollect"				
					}
			}
	
		Counters = @{
					Path = $CountersLogDirectory
					MaxSize = $MaxCountersCollectSize
					Excludes = $CheckSizeExcludes
					RenewConfig = @{
							Frequency 	= $RenewFrequencySeconds
							Func		= "CountersRenew"
						}
					Enabled = !$DisablePerfCollect
					SetupFunc = "SetupPerfCounterCollector";
					Prexec = @(
							"UpdateSqlInstanceCounters"
							"UpdateProcessCounters"
						)
				} 
				
	
		CountersHistory = @{
					Path = "$DirectoryPath\log_perfhistory"
					MaxSize = $MaxHistorySize
					ExcludeGlobal = $true
					Excludes = $CheckSizeExcludes
					RenewConfig = @{
							Frequency 	= $HistoryRenewFrequencySeconds
							Func		= "CountersHistoryRenew"
						}
					Enabled = ([bool]$MaxHistorySize)
					SetupFunc = "SetupCountersHistoryCollector";
					Prexec = @(
							"UpdateSqlInstanceCounters"
							"UpdateProcessCounters"
						)
					SampleInterval = $HistorySampleInterval
					MaxPerfCounterSize = $PerCounterFileMaxSize*2
				} 
				
				
		Process  = @{
					Path 	= $ProcessLogDirectory
					MaxSize = $MaxProcessCollectSize
					RenewConfig = @{
							Frequency 	= $ProcessLogSeconds/2 
							Func		= "DoProcessCollect"
						}
					Enabled = ([bool]$ProcessLogSeconds)
					SetupFunc = $null;
					IsAsync 	= ([bool]$ProcessLogJob)
					MaxRunTime	= $ProcessJobMaxRuntimeSeconds
				}
				
		Kernel	 = @{
					Path = $KernelLogDirectory
					MaxSize = $MaxKernelCollectSize
					RenewConfig = @{
							Frequency 	= $KernelRenewSeconds
							Func		= "KernelRenew"
						}
					Enabled = $KernelLogEnabled
					SetupFunc = "SetupKernelLogCollector";
				}
				
		xperf = @{
				Path 	= "$DirectoryPath\log_xperf"
				MaxSize = $MaxKernelCollectSize
				RenewConfig = @{
						Frequency 	= $KernelRenewSeconds
						Func		= "XPerfRenew"
					}
				Enabled = ([bool]$XPerfEnabled)
				IsAsync = ([bool]$XPerfJob)
				SetupFunc = "XPerfSetup";
				JobMaxRuntimeSeconds = $KernelRenewSeconds*4
			}
				
				
		Sql = @{
					Path 	= "$DirectoryPath\log_sql"
					SqlPath = "$SettingsLogDirectory\sql"
					Enabled = ([bool]$SqlLogSeconds)
					RenewConfig = @{
							Frequency = $SqlLogSeconds/2
							Func = "DoSqlCollect"
						}
					CollectFrequencySeconds = $SqlLogSeconds
					IsAsync = ([bool]$SqlLogJob)
					JobMaxRuntimeSeconds = $SqlJobMaxRuntimeSeconds
					OutputType = $SqlLogType
					SqlCommands = @{
							RequestThreads = @{
									type = "csv"
									sql = "
										SELECT
											R.session_id
											,R.command
											,R.last_wait_type
											,OT.os_thread_id
											,S.scheduler_id
											,S.cpu_id
											,Ts = GETDATE()
										FROM
											sys.dm_exec_requests R
											INNER JOIN
											sys.dm_os_tasks T
												ON T.session_id  = R.session_id
												AND T.request_id = R.request_id
											INNER JOIN
											sys.dm_os_workers W
												ON W.worker_address  = T.worker_address
											JOIN
											sys.dm_os_threads OT 
												ON OT.worker_address  = W.worker_address
											JOIN
											sys.dm_os_schedulers S
												ON S.scheduler_address = W.scheduler_address
									"	
							}
						}
			}
			
	}
	
	log "Total Collects: $($COLLECTS.count)"
	
	$ACTIVE_COLLECTS = @{};
	$COLLECTS.GetEnumerator() | ? { $_.value.Enabled } | %{
		$ACTIVE_COLLECTS[$_.key] = $_.value;
		$_.value.RuntimeData = @{};
 	};

	$MaxScriptRuntimeSeconds = Human2Secs $MaxScriptRuntime
	log "Script max runtime is $MaxScriptRuntime ($MaxScriptRuntimeSeconds secs)";
	
	
	log "Loading collects";
	$BadSleep = $false;
	$CollectControl = @{}
	$MinFrequencySeconds = $null;
	$MinFrequencyCollect = $null
	$PREXECS = @();
	$ACTIVE_COLLECTS.GetEnumerator() | %{
		$Config			= $_.value;
		$Enabled 		= $Config.Enabled;
		$SetupFunction 	= $Config.SetupFunc;	
		$CollectName	= $_.key;
		$RenewSeconds	= $Config.RenewConfig.Frequency
		$Path 			= $Config.Path;
		$PrexecList		= $Config.Prexec;
		
		if(!$Enabled){
			return;
		}
		
		if($SetupFunction -and -not(get-item -EA SilentlyContinue  "Function:\$SetupFunction")){
			throw "INVALID_SETUP_FUNCITON: $SetupFunction | Collect: $CollectName"
		}
		
		
		
		if($SleepTime -gt $RenewSeconds){
			log "SleepTime grather than renew frequency of $CollectName. $SleepTime > $RenewSeconds";
			$BadSleep = $true;
		}
		
		if($MinFrequencySeconds -eq $null -or $RenewSeconds -lt $MinFrequencySeconds){
			$MinFrequencySeconds = $RenewSeconds;
			$MinFrequencyCollect = $CollectName
		}
		
		log "Loaded collect $($CollectName)";
	
		$CollectControl[$CollectName] = @{
				LastRenew 	= $null	
				config 		= $_.value;
			}
			
		#Create the durectory pat...
		if(-not(Test-Path $Path)){
			log "Creating collect directory path for $CollectName on $Path";
			$nd = mkdir $Path;
		}
		
		#Have prexec?
		if($PrexecList){
			$PREXECS += $PrexecList;
		}
	}
	
	$PREXECS = $PREXECS | sort -Unique;
	
	if($BadSleep){
		throw "BAD_SLEEPTIME: Sleep time grather than some frequency. Check previous log messages";
	}
	
	log "	Total active collections: $($ACTIVE_COLLECTS.count) | Control: $($CollectControl.count)"

	$ProgressFrequencySeconds = $MinFrequencySeconds * 2;
	
	if($ProgressFrequencySeconds -gt $MaxScriptRuntimeSeconds){
		$ProgressFrequencySeconds = $MaxScriptRuntimeSeconds/2;
	}
	
	if($ManualProgressFrequency){
		log "ATTENTION: Progress frequency manually set";
		$ProgressFrequencySeconds = $ManualProgressFrequency;
	}
	
	log "Progress check frequency will be: $ProgressFrequencySeconds (MinFrequencyCollect = $MinFrequencyCollect | Min = $MinFrequencySeconds)"


	
	#Here will implement a loop that manages the collection...
	#We create a data collector that automatically create new files when ma size is reached...
	#	but, dc dont remove old files... This can result in problem in disk... So we need this powershell loop to monitor and manage disk space...
	#	Also, thanks to this part, we can keep data collector creating new files after some confingurables time...
	#	So, with data collector configurations set and this part, we have a collector with constraints on file size, total size and time.
	#		this is not possible just with default data collector set (or constraint is size or time).
	#	In addition, we create data collector with time constraint... So this loop is responsible for renew this time...
	#		If this powershell process stops unexpectdelly,logman will stop generates files, because this powershell will not renew it...

	log "Setting process priority class to $PriorityClass";
	SetPriorityClass $PriorityClass;
	
	log "Setting up collector for first time...";
	SetupCollection -FirstTime
	

	$MeProc = (Get-Process -Id $pid);
	
	
	log "First progress updateprogress info";
	UpdateProgress
	log "	Done!";
	
	log "Starting progress monitoring job";
	$MonitoringJob = StartProgressMonitoring
	log  "	Done"
	
	log "Starting collector and monitoring...";
	$i = 0;
	while($true){
		$i++;
		
		if($MaxScriptRuntimeSeconds){
			$Elapsed = (Get-Date) - $ScriptStartTime;
			
			if($Elapsed.totalSeconds -gt $MaxScriptRuntimeSeconds){
				log "Script will end due to max run time of $MaxScriptRuntimeSeconds secs. Any data collector running will keep running";
				break;
			}
		}
		
		$StartProcessorTime = $MeProc.TotalProcessorTime
		$StartKernelTime = $MeProc.PrivilegedProcessorTime
		$StartTime = (Get-Date);
		
		#Check renew...
		$StartCollectCPU = $MeProc.TotalProcessorTime
		foreach($Collect in $CollectControl.GetEnumerator()){
			$CollectName 	= $Collect.key;
			$Control		= $Collect.Value;
			$Config 		= $Control.config;
			
			log -v "COLLECT RENEW CHECK: $COllectName";
			$LastRenew 		= $Control.LastRenew;
			$RenewSeconds 	= $Config.RenewConfig.Frequency;
			
			if($LastRenew){
				$ElapsedRenew = (Get-Date) - $LastRenew;
				if($ElapsedRenew.totalSeconds -lt $RenewSeconds){
					log -v "	Renew not arrived. Sleeping. Elapsed: $ElapsedRenew | Frequency: $RenewSeconds";
					continue;
				}
			}
			
			$Control.LastRenew = (Get-Date);
			$RenewFunction = $Config.RenewConfig.Func;
			
			if(!$RenewFunction){
				throw "COLLECT $CollectName without a renew function";
			}
			
			if(-not(get-item -EA SilentlyContinue "function:\$RenewFunction")){
				throw "COLLECT $CollectName rewnw function $RenewFunction not found";	
			}
			
			log -v "	About to run RenewFunction $RenewFunction";
			& $RenewFunction $CollectName $Config;
			log -v "		Renew function ran successfuly!" 
		
		}
		$TotalCollectCPU = ($MeProc.TotalProcessorTime - $StartCollectCPU).totalMilliseconds;
		
		#Do important checks if its time to do it...
		DoChecks		
		
		#If returns true, some change occurred, must reinit...
		$EnvChanges = DoCheckEnvChanges		
		
		#Some cleanups...

		if($CleanupSeconds){
			$Cleanup = $true;
			if($LastCleanup){
				$Elapsed = (Get-Date) - $LastCleanup;
				if($Elapsed.TotalSeconds -lt $CleanupSeconds){
					$Cleanup = $false;
				}
			}
			
			if($Cleanup){
				DoCleanups;
				$LastCleanup = (Get-Date);
			}
		}
		
		$Endtime = (Get-Date);
		$TotalCPUTime = $($MeProc.TotalProcessorTime - $StartProcessorTime).totalMilliseconds;
		$TotalKernelTime = $($MeProc.PrivilegedProcessorTime - $StartKernelTime).totalMilliseconds;
		$TotalTime = ($Endtime - $StartTime).totalMilliseconds;
		
		log -v "Checking verbose runtime enabled";
		CheckVerboseEnabled
		
		#Update progress to monitoring...
		UpdateProgress
		
		
		log -v "Sleeping for $SleepTime (CPU t = $TotalCPUtime , k = $TotalKernelTime, e = $totalTime, collect = $TotalCollectCPU)";
		Start-Sleep -s $SleepTime;
	}
	
	log "Ending monitoring job...";
	KillJob $MonitoringJob;

	log "Script Ended Successfully";
} catch {
	log $_;
}

<#
	.DESCRIPTION
		Starts logman sessions to collect important metric to troubleshooting SQL Server issues.
		
		HISTORY
		
			v1.4.1 - Minor fixes
				- Fixed Result.error when handling connection error to sql server and csv mode.
				- Added a check to ignore Windows internal database (MICROSOFT##WID)
				
				
			v1.4.0 - Added support for xperf!
				Added a new collector: xperf! It replaces kernel when using parameter XPerfLog.
				
				Minor change: Added validatset to PriorityClass parameter
			
			v1.3.0 - Changes in sql collect
				Add parameters toc ontrol output file. Can be .csv or .xml (generated with *-clixml cmdlets)
				Default now is csv.
				
				Fix bug in cluster check.
				Add to check check if cluster service is installed.
		
			v1.2.1 - Minor enhacements
				Minor logggin enhacements to bring more info.
			
			v1.2 - New features
				Addes support for history counter collector. now its collects some performance counters in hgih sampling, but keep more time to history.
				Also, it select less counters.
				
				Removed use of NoShowConfig parameters. It become deprecrated and dont have function. Is Present only for backward compatibility.
				
				To implements these new functionalaty, some internal enhacements on some functions was made.
			
			
			v1.1.5 - Minor enhacements.
				Enhanced handling of errors when removing files on CheckDirSize
				Now, it will try remove each file, if fails for any reason, it logs to log and go next file.
				Now it also dont do more in a loop. It will try removed all files one time and not check total size again.
				This is for prevent it stay in a infinite loop if all files cannot be removed for some reason.
				
				Added check verbose runtime enabled at start for cases where log.parameters.txt is already present with verbose enabled.
				
				MaxSize of SQL log file increase to 20MB
				Documented sql parameters and added SqlLogMaxSize parameter to control size each collect file.
				
				Minor enhacement on Bytes2human and secs2human.
					
			
			v1.1.4 - Fixes on KernelAdditionalFlags parameters typos
				
			
			v1.1.3 - Enhacements on data collector configuration
				Replaced logman by Com in perfcounters.
				Added a filename to be generated using timestamp to avoid overwriting.
			
			v1.1.2 - Minor bug fixes on cleanup routine.
				Cleanup routine was getting directories paths due to -recurse param.
				When removing, powershell asking input from user,  hanging process...
			
			v1.1.0 - Lot of enhacements - Rodrigo Ribeiro Gomes
			
				- Documentation
					- Changed to powershell documentation syntax
					- Changed to english
					- Added history
				- Change many aspects of script
			
				author: Rodrigo Ribeiro Gomes
				github: @rrg92
				Twitter: @rod_rrg
			
			
			v0.9 - Ready for production
			
				Author: Luciano Caixeta Moreira
				http://luticm.blogspot.com
				Twitter: @luticm
				Blog: http://luticm.blogspot.com
				E-mail: luciano.moreira@srnimbus.com.br
				

			
#>

