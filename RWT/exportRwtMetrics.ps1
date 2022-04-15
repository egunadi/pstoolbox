# Configurable parameters
$parent_path = "D:\MedinformatixRwtExports"
$sqlinstance = "localhost"
$database = "medical"
# Set to customer Name when installing the script
$customer = "{Customer Name}"
# Set to Customer Care Setting when installing the script
$caresetting = "{Customer Care Setting}"
# Set to start date of the 90-day measurement period (defaults to current day)
## This should be dynamic if run using a scheduled job
## For one-time runs, this can be customized as such: 
## $startdate =  (Get-Date -Year 2022 -Month 1 -Day 1).ToString("yyyyMMdd")
$startdate = (Get-Date).ToString("yyyyMMdd")

# Ensure "Export" and "Archive" directories exist
$date_time = Get-Date -Format yyyyMMddHHmm
$export_path = $parent_path + "\Export"
$archive_path = $parent_path + "\Archive"
New-Item -Path $export_path -ItemType "directory" -Force
New-Item -Path $archive_path -ItemType "directory" -Force

# Archive last export
$new_archive = $archive_path + "\" + $date_time
New-Item -Path $new_archive -ItemType "directory" 
$last_export = $export_path + "\*.csv"
Move-Item -Path $last_export -Destination $new_archive

# EnableException for all dbatools commands so that the catch block is hit
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['*-Dba*:SqlInstance'] = $sqlinstance
$PSDefaultParameterValues['*-Dba*:Database'] = $database
$PSDefaultParameterValues['Select-Object:Property'] = "*"
$PSDefaultParameterValues['Select-Object:ExcludeProperty'] = "RowError", "RowState", "Table", "ItemArray", "HasErrors"

try {
  # Run stored proc and output result as CSV
  $file_path = $export_path + "\rwtMetrics." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.rwt_getmetrics `
      @i_customer=@customer, @i_caresetting=@caresetting, @i_startdate=@startdate" `
    -SqlParameters @{ customer=$customer; caresetting=$caresetting; startdate=$startdate } |  
  Select-Object | 
  Export-Csv -Path $file_path -NoTypeInformation
}
catch {
  $errormsg = $_.Exception.GetBaseException()
  Write-Output "There was an error - $errormsg"
  [System.Environment]::Exit(1)
}
