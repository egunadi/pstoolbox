# Configurable parameters
$export_path = "."
$sqlinstance = "localhost"
$database = "madmax"
$company = "MAIN"
$include_insurance = 1

# Not needed for Windows auth
$password = ConvertTo-SecureString "Tech1234" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("sa", $password) 

$date_time = Get-Date -Format yyyyMMddHHmm
$file_path = $export_path + "/waystarUpload." + $date_time + ".pat"

# EnableException for all dbatools commands so that the catch block is hit
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['Invoke-DbaQuery:SqlInstance'] = $sqlinstance
$PSDefaultParameterValues['Invoke-DbaQuery:Database'] = $database
# SqlCredential not needed for Windows auth
$PSDefaultParameterValues['Invoke-DbaQuery:SqlCredential'] = $cred 

# Run stored procs and output results as CSVs
try {
  (Invoke-DbaQuery -Query "exec dbo.wspc_generateData `
      @i_company=@company, @i_include_insurance=@include_insurance" `
    -SqlParameters @{ company=$company; include_insurance=$include_insurance } |  
  Select-Object | 
  ConvertTo-Csv -NoTypeInformation).Split("`n").TrimStart('"').TrimEnd('"') |
  Select-Object -Skip 1 |
  Set-Content -Path $file_path
}
catch {
  $errormsg = $_.Exception.GetBaseException()
  Write-Output "There was an error - $errormsg"
  [System.Environment]::Exit(1)
}
