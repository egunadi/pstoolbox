# Configurable parameters
$parent_path = "D:\MedinformatixHefExports"
$sqlinstance = "localhost"
$database = "medical"
$company = "MAIN"

$date_time = Get-Date -Format yyyyMMddHHmm
$export_path = $parent_path + "\Box Sync"
New-Item -Path $export_path -ItemType "directory" -Force

# EnableException for all dbatools commands so that the catch block is hit
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['Invoke-DbaQuery:SqlInstance'] = $sqlinstance
$PSDefaultParameterValues['Invoke-DbaQuery:Database'] = $database
$PSDefaultParameterValues['Select-Object:Property'] = "*"
$PSDefaultParameterValues['Select-Object:ExcludeProperty'] = "RowError", "RowState", "Table", "ItemArray", "HasErrors"

# Run stored procs and output results as CSVs
try {
  $datefrom = (Invoke-DbaQuery -Query "select min(convert(varchar(8), DATEIN, 112)) from dbo.CLLAB")
  $datefrom = [Datetime]::ParseExact($datefrom.Column1, 'yyyyMMdd', $null).ToString("yyyyMMdd")

  $dateto = (Invoke-DbaQuery -Query "select max(convert(varchar(8), DATEIN, 112)) from dbo.CLLAB")
  $dateto = [Datetime]::ParseExact($dateto.Column1, 'yyyyMMdd', $null).ToString("yyyyMMdd")

  $labs_path = $export_path + "\labs_full." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getlabs `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $labs_path -NoTypeInformation
}
catch {
  $errormsg = $_.Exception.GetBaseException()
  Write-Output "There was an error - $errormsg"
  [System.Environment]::Exit(1)
}
