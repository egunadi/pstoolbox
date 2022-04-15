# Configurable parameters
$sqlinstance = "localhost"
# Set to location of ps1 export file
$exportscript = "D:\MedinformatixHefExports\ExportHefData.ps1"
# Set StartTime of Agent Schedule in HHMMSS format 
## Note that using a non-round number (ex. '000248' for midnight) is best practice
$starttime = "000248"
# Set names for Credential and Proxy used to run the Agent Job
$credentialname = "Medinformatix Proxy Account"
$proxyname = "Medinformatix Proxy" 
# Set Agent Job name
$jobname = 'MedInformatix Hef Export'

$PSDefaultParameterValues['*-Dba*:SqlInstance'] = $sqlinstance

# Create a new SQL credential if one doesn't already exist
$credentials = Get-DbaCredential
if ($credentials.Name -notcontains $credentialname)
{
    # create credential object for the user for the credential
    $credential = Get-Credential -Message "Enter the Username and Password for the credential"
    
    $credsplat = @{
        SecurePassword = $credential.Password
        Name = $credentialname
        Identity = $credential.UserName
    }
    New-DbaCredential @credsplat
} 

# Create a new proxy if one doesn't already exist
$proxies = Get-DbaAgentProxy
if ($proxies.Name -notcontains $proxyname)
{
    $proxysplat = @{
        ProxyCredential = $credentialname
        Name = $proxyname
        SubSystem = 'CmdExec'
    }
    New-DbaAgentProxy @proxysplat
}  

# Create a SQL Job to run a PowerShell script
$agentjobs = Find-DbaAgentJob -JobName *export*
if ($agentjobs.Name -notcontains $jobname)
{
    # Creating a new Agent Schedule for jobs to run on the first of the month
    $schedulename = 'Monthly-1st-Midnight'
    $schedulesplat = @{
        FrequencyType = 'Monthly'
        Schedule = $schedulename
        Force = $true
        StartTime = $starttime
        FrequencyInterval = 1
    }
    New-DbaAgentSchedule @schedulesplat

    $jobsplat = @{
        OwnerLogin = 'sa'
        Job = $jobname
        Schedule = $schedulename
        EventLogLevel = 'OnFailure'
        Force = $true
    }
    New-DbaAgentJob @jobsplat

    $command = 'powershell.exe -File ' + $exportscript + ' -ExecutionPolicy bypass'
    $stepsplat = @{
        Subsystem = 'CmdExec'
        Command = $command
        StepName = 'Run exportRwtMetrics.ps1'
        Job = $jobname
        ProxyName = $proxyname
        Flag = 'AppendAllCmdExecOutputToJobHistory' 
    }
    New-DbaAgentJobStep @stepsplat
} 

