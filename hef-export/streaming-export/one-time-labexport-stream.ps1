# Configurable parameters
$parent_path = "D:\MedinformatixHefExports"
$sqlinstance = "localhost"
$database = "medical"
$company = "RENAL"

$exportcmdlet = $parent_path + "\Export-StreamCsv.ps1"

$date_time = Get-Date -Format yyyyMMddHHmm
$export_path = $parent_path + "\Box Sync"
New-Item -Path $export_path -ItemType "directory" -Force

# EnableException for all dbatools commands so that the catch block is hit
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['Invoke-DbaQuery:SqlInstance'] = $sqlinstance
$PSDefaultParameterValues['Invoke-DbaQuery:Database'] = $database

$datefrom = (Get-Date -Day 1 -Month 1 -Year 2010).ToString("yyyyMMdd")
$dateto = (Invoke-DbaQuery -Query "select max(convert(varchar(8), DATEIN, 112)) from dbo.CLLAB")
$dateto = [Datetime]::ParseExact($dateto.Column1, 'yyyyMMdd', $null).ToString("yyyyMMdd")

# Run stored procs and output results as CSVs
$labs_path = $export_path + "\labs_full." + $date_time + ".csv"
$labs_query = "exec dbo.hef_getlabs @i_company='" + $company + `
  "', @i_xacdatefrom='" + $datefrom + "', @i_xacdateto='" + $dateto + "'"
& $exportcmdlet -query $labs_query -exportpath $labs_path
  