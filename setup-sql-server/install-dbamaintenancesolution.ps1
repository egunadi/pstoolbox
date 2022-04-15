# https://docs.dbatools.io/#Install-DbaMaintenanceSolution

 $params = @{
    SqlInstance = 'SQLSERVER01'
    Database = 'medical'
    ReplaceExisting = $true
    InstallJobs = $true
    CleanupTime = 72
    Verbose = $true
}
Install-DbaMaintenanceSolution @params 
