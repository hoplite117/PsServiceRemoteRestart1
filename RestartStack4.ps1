#prompt for stack name
param([string]$stack)
if (!$stack){
write-host "Stack name variable cannot be null. Run script again with a -stack argument" -foregroundcolor red
Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
return
}

#confirm stack name

#build service array
$services = ("CBExecutive","CMP01","Not stopped","Not started"),("ALERTS_CONTROLLER", "CMP01","Not stopped","Not started"),("JBCBALRTSVC", "CMP01","Not stopped","Not started")

#create functions
function endStackService ([string]$serviceName, [string]$stackName, [string]$serverName){
	$endStackService = invoke-command -computername $serverName -scriptblock {stop-service -name $serviceName} 
	$endStackServiceResults = invoke-command -computername $serverName -scriptblock {get-service -name $serviceName | select-object -expandproperty status}
	$stackServicePID = invoke-command -computername $serverName -scriptblock {$wmiPID = Get-WmiObject -Class win32_service -Filter "name=$serviceName"; $wmiPID.processid}
	if ($endStackServiceResults -neq "Stopped"){
		invoke-command -computername $serverName -scriptblock {stop-process -ID $stackServicePID}
	}  
}
function statusStackService ([string]$serviceName, [string]$stackName, [string]$serverName){
	invoke-command -computername $serverName -scriptblock {get-service -name $serviceName | select-object -expandproperty Status}
}
function startStackService ([string]$serviceName, [string]$stackName, [string]$serverName){
	$startStackServiceResults = invoke-command -computername $serverName -scriptblock {get-service -name $serviceName | select-object -expandproperty status}
	if ($startStackServiceResults -eq "Stopped"){
		$startStackService = invoke-command -computername $serverName -scriptblock {start-service -name $serviceName}
	}  
}
function endJobs {
	write-host "Waiting for all jobs to complete"
	while ((get-job -state running) -neq $null)
	{
	}
	write-host "All jobs have ended"
	remove-job -state Completed
}

#stop services in background jobs
foreach ($service in $services){
	write-host "Stopping " + $service[0]
	start-job -name ($service[0] + "StopJob") -ScriptBlock {endStackService $service[0] $stack $service[1]}
} 

#wait for all jobs to complete
endJobs

#start services in background jobs
foreach ($service in $services){
	write-host "Starting " + $service[0]
	start-job -name ($service[0] + "StartJob") -ScriptBlock {startStackService $service[0] $stack $service[1]}
} 

#wait for all jobs to complete
endJobs

#show status of services
foreach ($service in $services){
	write-host $service[0] + " is: "
	statusStackService $service[0] $stack $service[1]
} 

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
