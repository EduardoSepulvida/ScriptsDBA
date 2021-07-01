#Script to implant SQLPerfCollect on PowerTuning customers
param(
	 $BaseDirectory = $null
	,[switch]$ScriptRootBase
	,$TaskScheduleFolder = '\DBA'
	,$TaskName = 'PowerTuning_SqlPerfCollect'
	,$TaskPriority = $null
	,[string]$MaxSize =  '10GB'
	,[string]$ProcessLogFrequency = 10
	,[switch]$RecreateStartScript
	,[switch]$ProcessLogJob
	,[ValidateSet("Advanced","SqlProcAsync","Basic","AdvancedWThread")]
		$StartProfile = "Basic"
	,[switch]$IncludeHistory
)

$ErrorActionPreference = "Stop";

$TemplateXML = [xml]'<?xml version="1.0" encoding="UTF-8"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2020-11-11T21:00:19.1018606</Date>
    <Author>Power Tuning</Author>
    <Description>Collects performance metric data efficiently to be Analyzed by PowerTuning team if some problem serious problems occurs</Description>
    <URI>\DBA\PowerTuning_SqlPerfCollect</URI>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <Repetition>
        <Interval>PT1M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>2020-01-01T00:00:00-03:00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>5</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-File %BaseDir%\StartPerfCollect.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
'

#Created scheduled task folder...
function ImportScheduledTask {
	param()
	
	$TempFile 		= [Io.Path]::GetTempFileName();
	$TempFileXML	= $TempFile+'.xml';
	
	$RegistrationDate 	= (Get-Date).toString('yyyy-MM-ddTHH:mm:ssK');
	$NextStart 			= (Get-Date).addMinutes(2).toString('yyyy-MM-ddTHH:mm:ssK');
	
	#Change some props...
	$TemplateXML.Task.RegistrationInfo.Date = $RegistrationDate;
	$TemplateXML.Task.Triggers.CalendarTrigger.StartBoundary = $NextStart;
	$ExecArgs = $TemplateXML.Task.Actions.Exec.Arguments
	$TemplateXML.Task.Actions.Exec.Arguments = $ExecArgs.replace('%BaseDir%',$BaseDirectory)
	
	if($TaskPriority.length){
		$TemplateXML.Task.Settings.Priority = [string]$TaskPriority;
	}

	$UnicodeEncoding = New-Object System.Text.UnicodeEncoding
	$UnicodeWriter 	= New-Object System.IO.StreamWriter($TempFileXML, $false, $UnicodeEncoding)
	try {
		write-host "Generating task xml at $TempFileXML";
		$TemplateXML.save($UnicodeWriter);
	} finally {
		$UnicodeWriter.close();
	}
	write-host "	Done!";
	
	$FullTaskName = "$TaskScheduleFolder\$TaskName"
	
	write-host "Importing xml task from $TempFileXML";
	$Output = schtasks.exe /create /f /xml "$TempFileXML" /NP /TN "$FullTaskName";
	$ExitCode = $LastExitCode;
	
	
	if($ExitCode){
		throw "FAILED_IMPORT_TASK: ExitCode: $ExitCode. Output: $Output"
	}
	
	return
}



if(!$BaseDirectory){
	if(!$ScriptRootBase){
		throw "INVALID_BASE_DIRECTORY";
	}
	
	$BaseDirectory = "$PsScriptRoot"
	$DontCopyPerfCollect = $true;
}

$BaseDirItem = mkdir $BaseDirectory -force;

write-host "Checking SQLPerfCollect.ps1";
$PerfCollectScript = "$BaseDirectory\SQLPerfCollect.ps1";

#If there are in current, copy them...
$AlternateSQLPerf = "$PsScriptRoot\SQLPerfCollect.ps1";

if(!$DontCopyPerfCollect  -and (Test-path $AlternateSQLPerf)){
	write-host "Copying alternate SQLPerfCollect to alternate";
	copy $AlternateSQLPerf $BaseDirectory;
}

if(-not(Test-Path $PerfCollectScript)){
	throw "SqlPerfCollect script dont found on destinaton abse diretory: $SqlPerfCollect";;
}

write-host "Checking StartFile";
$StartFile = "$BaseDirectory\StartPerfCollect.ps1";

if(-not(Test-Path $StartFile) -or $RecreateStartScript){

	$ScriptContentCall = '& "$PsScriptRoot\SQLPerfCollect.ps1" @ScriptParams';
	
	$BuildParams = @{
		Directory 				= '"$PsScriptRoot\collect"'
		NoShowConfig 			= $true
		PerCounterFileMaxSize 	= '25MB'
		MaxCollectSize 			= "$MaxSize"
	}
	
	write-host "Using profile $StartProfile";
	switch($StartProfile){
		"Advanced" {
			$BuildParams += @{
				KernelLog 	= $true
				KernelFlags	= 'process','thread','dispatcher','hard_faults','image_load','profile','cswitch','dpc','interrupt'
				ProcessLogFrequency	= 10
				ProcessLogJob = $true
				SqlLogFrequency = '1m'
				SqlLogJob = $true
			}
		}
		
		"AdvancedWThread" {
			$BuildParams += @{
				KernelLog 	= $true
				KernelFlags	= 'process','thread','dispatcher','hard_faults','image_load','profile','cswitch','dpc','interrupt'
				ProcessLogFrequency	= 10
				ProcessLogJob = $true
				SqlLogFrequency = '5m'
				SqlLogJob 		= $true
				CollectThreads	= $true
			}
		}
		
		"SqlProcAsync" {
			$BuildParams += @{
				ProcessLogJob 	= $true
				ProcessLogFrequency	= 10
				SqlLogFrequency = '1m'
				SqlLogJob 		= $true
			}
		}
	}
	
	if($IncludeHistory){
		$BuildParams['MaxHistorySize'] = '10GB'
		$BuildParams['HistoryDatabaseFull'] = $true
	}
	
	
	#Preparing builds params...
	$MaxLength = 0;
	@($BuildParams.keys) | %{
		if($_.Length -gt $MaxLength){
			$MaxLength = $_.Length;
		}
	}
	
	$MaxSpaces = $MaxLength + 4;
	$ScriptContentParamsAssign = @()
	
	foreach($Param in $BuildParams.GetEnumerator()){
		$ParamName 	= $Param.key;
		$ParamValue	= $Param.value;
		
		$ParamLength 	= $ParamName.length;
		$SpaceCount 	= $MaxSpaces - $ParamLength;	
		
		if($ParamValue -is [bool]){
			$StringValue = ('$'+[string]$ParamValue).toLower()
		} 
		elseif($ParamValue -is [object[]]) {
			$StringValue = @($ParamValue | %{"'$_'"}) -Join ","
		} elseif($ParamValue -is [string]) {
			$StrDelim =  '"',"'";
			
			if($ParamValue -match '\d+(.B)'){
				$StringValue = $ParamValue
			}elseif($ParamValue -match '^"[^"]+"$'){
				$StringValue = $ParamValue; 
			} else {
				$StringValue = "'$ParamValue'"
			}
			
		} else{
			$StringValue = [string]$ParamValue;
		}
		
		
		
		$ScriptContentParamsAssign += "`t"+$ParamName+(" " * $SpaceCount)+"= $StringValue";
	}
	
	$ScriptContentParams = @(
		'$ScriptParams = @{'
			@($ScriptContentParamsAssign|sort)
		'}'
	)
	
	$ScriptContent = @(
		$ScriptContentParams
		$ScriptContentCall
	) -Join "`r`n";
	
	if(Test-Path $StartFile){
		$ExistingContent  = Get-content $StartFile | %{
				$_.replace('<#','').replace('#>','');
			}
	}
	
	$ScriptName = Split-Path -Leaf $PSCommandPath
	
	@(
		"#Created using $ScriptName  at $(Get-Date)"
		"#Choosen profile: $($StartProfile)"
		""
		
		$ScriptContent 
		
		""
		"<#"
		"#Old version at $(get-date)"
		$ExistingContent
		"#>"
	) -Join "`r`n" > $StartFile;
}

write-host "Importing scheduled task..."
ImportScheduledTask
write-host "	Ok";


write-host "Setting ACL on $BaseDirectory";
try {

	$acl = New-Object System.Security.AccessControl.DirectorySecurity
	$acl.SetAccessRuleProtection($true,$false)
	$AdminAccountSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
	$AdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AdminAccountSid, 'FullControl','ContainerInherit,ObjectInherit','None','Allow')
	
	$AuthUsersSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-11')
	$ExecuteRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AuthUsersSid, 'ReadAndExecute','ContainerInherit,ObjectInherit','None', 'Allow')
	$acl.SetAccessRule($AdminRule);
	$acl.SetAccessRule($ExecuteRule);

	Set-Acl -LiteralPath $BaseDirectory -AclObject $acl

	gci $BaseDirectory | %{
		write-host "Setting acl on $_";
		Set-Acl -Path $_.FullName -AclObject $acl;
	}

	write-host " Done";

} catch {
	write-host "CANNOT SET ACL ON $BaseDirectory"
	write-host "SET MANUALLY: Set BUILTIN\Administrators full control"
	write-host "SET MANUALLY: Set authenticated users Read,Read and Execute and List contents (NO ALLOW ANY MODIFY)"
	write-host "SET MANUALLY: Enable inheritance to child directories"
	write-host "SET MANUALLY: Disable inheritance on TOP LEVEL"
	write-host "SET MANUALLY: Set for top level directory and each .ps1 files"
	write-host "SET MANUALLY: Remove any other users or group from this set"
	write-host "ATTENTION, BECAUSE SCRIPTS ON THIS FOLDERS RUNS AS ADMIN, ITS VITAL IMPORTANCE CHECK OTHER USERS IN ADDITIONA OF ADMINSTRATORS CANNOT MODIFY CONTENTS OF THEM!"
	throw;
	
}








