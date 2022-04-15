# Configurable parameters
$parent_path = "."
$sqlinstance = "localhost"
$database = "madmax"
$company = "MAIN"

# Not needed for Windows auth
$password = ConvertTo-SecureString "Tech1234" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("sa", $password) 

# $datefrom is used for @i_xacdatefrom parameters and should be the first day of the year
$datefrom = (Get-Date -Day 1 -Month 1 -Year 2020).ToString("yyyyMMdd")
# $dateto is used for @i_xacdateto parameters and should be the last day of last month
$dateto = (Get-Date -Day 1 -Month 1 -Year 2021).AddDays(-1).ToString("yyyyMMdd")
$date_time = Get-Date -Format yyyyMMddHHmm
$export_path = $parent_path + "/Box Sync"
$archive_path = $parent_path + "/Archive"
New-Item -Path $export_path -ItemType "directory" -Force
New-Item -Path $archive_path -ItemType "directory" -Force
$new_archive = $archive_path + "/" + $date_time
New-Item -Path $new_archive -ItemType "directory" 
$last_export = $export_path + "/*.csv"
Move-Item -Path $last_export -Destination $new_archive

# EnableException for all dbatools commands so that the catch block is hit
$PSDefaultParameterValues['*-Dba*:EnableException'] = $true
# ErrorAction Stop for all commands so that the catch block is hit
$PSDefaultParameterValues['*:ErrorAction'] = "Stop"
$PSDefaultParameterValues['Invoke-DbaQuery:SqlInstance'] = $sqlinstance
$PSDefaultParameterValues['Invoke-DbaQuery:Database'] = $database
$PSDefaultParameterValues['Find-DbaStoredProcedure:SqlInstance'] = $sqlinstance
$PSDefaultParameterValues['Find-DbaStoredProcedure:Database'] = $database
# SqlCredential not needed for Windows auth
$PSDefaultParameterValues['Invoke-DbaQuery:SqlCredential'] = $cred 
$PSDefaultParameterValues['Find-DbaStoredProcedure:SqlCredential'] = $cred 
$PSDefaultParameterValues['Select-Object:Property'] = "*"
$PSDefaultParameterValues['Select-Object:ExcludeProperty'] = "RowError", "RowState", "Table", "ItemArray", "HasErrors"

# Run stored procs and output results as CSVs
try {
  $billent_path = $export_path + "/billingEntities." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getbillingentities @i_company=@company" `
    -SqlParameters @{ company=$company } |  
  Select-Object | 
  Export-Csv -Path $billent_path -NoTypeInformation

  $providers_path = $export_path + "/providers." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getproviders @i_company=@company" `
    -SqlParameters @{ company=$company } |  
  Select-Object | 
  Export-Csv -Path $providers_path -NoTypeInformation

  $patients_path = $export_path + "/patients." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getpatients `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $patients_path -NoTypeInformation

  $encounters_path = $export_path + "/encounters." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getencounters `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $encounters_path -NoTypeInformation

  $problems_path = $export_path + "/problems." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getproblems `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $problems_path -NoTypeInformation

  $vitals_path = $export_path + "/vitals." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getvitals `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $vitals_path -NoTypeInformation

  $allergies_path = $export_path + "/allergies." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getallergies `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $allergies_path -NoTypeInformation

  $medications_path = $export_path + "/medications." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getmedications `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $medications_path -NoTypeInformation

  $labs_path = $export_path + "/labs." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getlabs `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $labs_path -NoTypeInformation

  $devices_path = $export_path + "/devices." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getdevices `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $devices_path -NoTypeInformation

  $immunizations_path = $export_path + "/immunizations." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getimmunizations `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $immunizations_path -NoTypeInformation

  $orders_path = $export_path + "/orders." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getorders `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $orders_path -NoTypeInformation

  $physicalexam_visualacuity_path = $export_path + "/physicalexam_visualacuity." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getphysicalexam_visualacuity `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $physicalexam_visualacuity_path -NoTypeInformation

  $procedures = Find-DbaStoredProcedure -Pattern hef_getdiagnosticstudy_measure143
  if ($procedures.Name -contains 'hef_getdiagnosticstudy_measure143')
  {
    $diagnosticstudy_measure143_path = $export_path + "/diagnosticstudy_measure143." + $date_time + ".csv"
    Invoke-DbaQuery -Query "exec dbo.hef_getdiagnosticstudy_measure143 `
        @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
      -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |
    Select-Object |
    Export-Csv -Path $diagnosticstudy_measure143_path -NoTypeInformation
  }

  $assessments_tobacco_path = $export_path + "/assessments_tobacco." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.hef_getassessments_tobacco `
      @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
    -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |
  Select-Object |
  Export-Csv -Path $assessments_tobacco_path -NoTypeInformation

  $pi_medicare_path = $export_path + "/pi_medicare." + $date_time + ".csv"
  Invoke-DbaQuery -Query "exec dbo.midash_ACI_RESULTS_2020_HEF `
      @dateStart=@datefrom, @dateStop=@dateto" `
    -SqlParameters @{ datefrom=$datefrom; dateto=$dateto } |  
  Select-Object | 
  Export-Csv -Path $pi_medicare_path -NoTypeInformation

  $procedures = Find-DbaStoredProcedure -Pattern hef_getphysicalexam_eyeexam
  if ($procedures.Name -contains 'hef_getphysicalexam_eyeexam')
  {
    $physicalexam_eyeexam_path = $export_path + "/physicalexam_eyeexam." + $date_time + ".csv"
    Invoke-DbaQuery -Query "exec dbo.hef_getphysicalexam_eyeexam `
        @i_company=@company, @i_xacdatefrom=@datefrom, @i_xacdateto=@dateto" `
      -SqlParameters @{ company=$company; datefrom=$datefrom; dateto=$dateto } |
    Select-Object |
    Export-Csv -Path $physicalexam_eyeexam_path -NoTypeInformation
  }
}
catch {
  $errormsg = $_.Exception.GetBaseException()
  Write-Output "There was an error - $errormsg"
  [System.Environment]::Exit(1)
}
